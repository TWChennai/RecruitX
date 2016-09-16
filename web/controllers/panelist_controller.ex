defmodule RecruitxBackend.PanelistController do
  use RecruitxBackend.Web, :controller

  alias RecruitxBackend.InterviewPanelist
  alias RecruitxBackend.Panel
  alias RecruitxBackend.SlotPanelist
  alias RecruitxBackend.ChangesetView
  alias RecruitxBackend.ErrorView
  alias RecruitxBackend.Candidate
  alias Swoosh.Templates
  alias RecruitxBackend.MailHelper
  alias Timex.DateFormat
  alias Timex.Date
  alias Timex.Timezone

  @api_key System.get_env("API_KEY")
  @api_url System.get_env("API_URL")

  def web_signup(conn = %Plug.Conn{cookies: %{"panelist_role" => panelist_role,
  "username" => panelist_login_name}}, %{"interview_id" => interview_id,
  "panelist_experience" => panelist_experience}) do
    post_params =
    %{ "interview_panelist" =>
      %{
        "interview_id" => interview_id,
        "panelist_login_name" => panelist_login_name,
        "panelist_experience" => panelist_experience,
        "panelist_role" => panelist_role
       }
    }
    json_request = Poison.Encoder.encode(post_params, [])
    response = HTTPotion.post("#{@api_url}/panelists",
    [body: json_request, headers: ["Authorization": @api_key, "Content-Type":
    "application/json"]])
    {_, parsed_response} = Poison.Parser.parse(response.body)
    case response.status_code do
      201 ->
        conn
        |> put_status(:created)
        |> render("panelist_web.json", interview_panelist: parsed_response |> convertKeysFromStringsToAtoms)
      _ ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(ErrorView, "bad_request.json", %{error: %{signup: ["sign up
        failed"]}})
    end
  end

  def convertKeysFromStringsToAtoms(input) do
    for {key, val} <- input, into: %{}, do: {String.to_atom(key), val}
  end

  def create(conn, %{"interview_panelist" => %{"panelist_role" => _ ,"panelist_experience" => _} = post_params}) do
    interview_panelist_changeset = InterviewPanelist.changeset(%InterviewPanelist{}, post_params)
    case Repo.insert(interview_panelist_changeset) do
      {:ok, interview_panelist} ->
        conn
        |> put_status(:created)
        |> put_resp_header("location", panelist_path(conn, :show, interview_panelist))
        |> render("panelist.json", interview_panelist: interview_panelist)
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(ChangesetView, "error.json", changeset: changeset)
    end
  end

  def create(conn, %{"interview_panelist" => _}), do: conn |> put_status(400) |> render(RecruitxBackend.ChangesetView, "missing_param_error.json", param: "panelist_experience/panelist_role")


  def create(conn, %{"slot_panelist" => %{"panelist_role" => _ ,"panelist_experience" => _} = slot_panelist_params}) do
    changeset = SlotPanelist.changeset(%SlotPanelist{}, slot_panelist_params)

    case Repo.insert(changeset) do
      {:ok, slot_panelist} ->
        conn
        |> put_status(:created)
        |> put_resp_header("location", panelist_path(conn, :show, slot_panelist))
        |> render("panelist.json", slot_panelist: slot_panelist)
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(RecruitxBackend.ChangesetView, "error.json", changeset: changeset)
    end
  end

  def create(conn, %{"slot_panelist" => _}), do: conn |> put_status(400) |> render(RecruitxBackend.ChangesetView, "missing_param_error.json", param: "panelist_experience/panelist_role")

  def delete(%{path_info: ["panelists", _]} = conn, %{"id" => id}) do
    Repo.delete_all(from i in InterviewPanelist, where: i.id == ^id)
    send_resp(conn, :no_content, "")
  end

  def delete(%{path_info: ["remove_panelists", _]} = conn, %{"id" => id}) do
    send_notification_to_panelist(id)
    send_notification_to_other_panelist(id)
    Repo.delete_all(from i in InterviewPanelist, where: i.id == ^id)
    send_resp(conn, :no_content, "")
  end

  def delete(%{path_info: ["decline_slot", _]} = conn, %{"id" => id}) do
    Repo.delete_all(from i in SlotPanelist, where: i.id == ^id)
    send_resp(conn, :no_content, "")
  end

  defp send_notification_to_panelist(id) do
    {candidate_first_name, candidate_last_name, interview_name, panelist_login_name, start_time} =
      (from c in Candidate, join: i in assoc(c, :interviews), join: ip in assoc(i, :interview_panelist), join: it in assoc(i, :interview_type), where: ip.id == ^id, select: {c.first_name, c.last_name, it.name, ip.panelist_login_name, i.start_time}) |> Repo.one

    {:ok, interview_date} = Date.from(start_time) |> Timezone.convert("Asia/Kolkata") |> DateFormat.format("%b-%d", :strftime)
    email_content = Templates.panelist_removal_notification(true, candidate_first_name, candidate_last_name, interview_name, interview_date)
    send_mail_with_content(panelist_login_name, email_content)
  end

  defp send_notification_to_other_panelist(id) do
    interview_id = Repo.get(InterviewPanelist, id).interview_id
    other_panelist = (from c in Candidate, join: i in assoc(c, :interviews), join: ip in assoc(i, :interview_panelist), join: it in assoc(i, :interview_type), where: ip.id != ^id and ip.interview_id == ^interview_id, select: {c.first_name, c.last_name, it.name, ip.panelist_login_name, i.start_time}) |> Repo.one
    if !is_nil(other_panelist) do
      {candidate_first_name, candidate_last_name, interview_name, panelist_login_name, start_time} = other_panelist
      {:ok, interview_date} = Date.from(start_time) |> Timezone.convert("Asia/Kolkata") |> DateFormat.format("%b-%d", :strftime)
      email_content = Templates.panelist_removal_notification(false, candidate_first_name, candidate_last_name, interview_name, interview_date)
      send_mail_with_content(panelist_login_name, email_content)
    end
  end

  defp send_mail_with_content(panelist_login_name, email_content) do
    MailHelper.deliver(%{
      subject: "[RecruitX] Change in interview panel",
      to: [panelist_login_name |> Panel.get_email_address],
      html_body: email_content
    })
  end
end
