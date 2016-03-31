defmodule RecruitxBackend.Interview do
  use RecruitxBackend.Web, :model

  alias Ecto.Changeset
  alias RecruitxBackend.Candidate
  alias RecruitxBackend.ChangesetManipulator
  alias RecruitxBackend.FeedbackImage
  alias RecruitxBackend.InterviewPanelist
  alias RecruitxBackend.InterviewStatus
  alias RecruitxBackend.InterviewStatus
  alias RecruitxBackend.InterviewType
  alias RecruitxBackend.InterviewTypeRelativeEvaluator
  alias RecruitxBackend.PipelineStatus
  alias RecruitxBackend.Repo
  alias RecruitxBackend.SignUpEvaluator
  alias RecruitxBackend.TimexHelper
  alias Timex.Date
  alias Timex.DateFormat

  import Ecto.Query

  @duration_of_interview 1

  schema "interviews" do
    field :start_time, Timex.Ecto.DateTime
    field :end_time, Timex.Ecto.DateTime
    belongs_to :candidate, Candidate
    belongs_to :interview_type, InterviewType
    belongs_to :interview_status, InterviewStatus

    timestamps

    has_many :interview_panelist, InterviewPanelist
    has_many :feedback_images, FeedbackImage
  end

  @required_fields ~w(candidate_id interview_type_id start_time)
  @optional_fields ~w(interview_status_id)

  def now_or_in_next_seven_days(query) do
    start_of_today = Date.set(Date.now, time: {0, 0, 0})
    from i in query, where: i.start_time >= ^start_of_today and i.start_time <= ^(start_of_today |> Date.shift(days: 7))
  end

  def default_order(query) do
    from i in query, order_by: [asc: i.start_time, asc: i.id]
  end

  def descending_order(query) do
    from i in query, order_by: [desc: i.start_time, asc: i.id]
  end

  def get_interviews_with_associated_data do
    (from i in __MODULE__,
      preload: [:interview_panelist, candidate: :candidate_skills],
      select: i)
  end

  def get_last_completed_rounds_start_time_for(candidate_id) do
    interview_with_feedback_and_maximum_start_time =
                              (from i in __MODULE__,
                              where: i.candidate_id == ^candidate_id and
                              not(is_nil(i.interview_status_id)),
                              order_by: [desc: i.start_time],
                              limit: 1)
                              |> Repo.one
    case interview_with_feedback_and_maximum_start_time do
      nil -> Date.set(Date.epoch, date: {0, 0, 1})
      _ -> interview_with_feedback_and_maximum_start_time.start_time
    end
  end

  def get_candidates_with_all_rounds_completed do
    (from i in __MODULE__,
      group_by: i.candidate_id,
      select: [i.candidate_id, max(i.start_time), count(i.candidate_id)])
  end


  def interviews_with_insufficient_panelists do
    __MODULE__
    |> join(:left, [i], ip in assoc(i, :interview_panelist))
    |> group_by([i], i.id)
    |> having([i], count(i.id) < ^InterviewPanelist.max_count)
  end

  def changeset(model, params \\ :empty) do
    model
    |> cast(params, @required_fields, @optional_fields)
    |> unique_constraint(:interview_type_id, name: :candidate_interview_type_id_index)
    |> validate_single_update_of_status()
    |> assoc_constraint(:candidate)
    |> assoc_constraint(:interview_type)
    |> assoc_constraint(:interview_status)
    |> is_in_future(:start_time)
    |> should_less_than_a_month(:start_time)
    |> calculate_end_time
  end

  #TODO: When end_time is sent from UI, validations on end time to be done
  defp calculate_end_time(existing_changeset) do
    incoming_start_time = existing_changeset |> get_field(:start_time)
    if is_nil(existing_changeset.errors[:start_time]) and !is_nil(existing_changeset.changes[:start_time]) do
      min_valid_end_time = incoming_start_time |> Date.shift(hours: @duration_of_interview)
      existing_changeset = existing_changeset |> put_change(:end_time, min_valid_end_time)
    end
    existing_changeset
  end

  def is_in_future(existing_changeset, field) do
    if is_nil(existing_changeset.errors[:start_time]) and !is_nil(existing_changeset.changes[:start_time]) do
      new_start_time = Changeset.get_field(existing_changeset, field)
      current_time = (Date.now |> Date.shift(mins: -5))
      valid = TimexHelper.compare(new_start_time, current_time)
      if !valid, do: existing_changeset = Changeset.add_error(existing_changeset, field, "should be in the future")
    end
    existing_changeset
  end

  def should_less_than_a_month(existing_changeset, field) do
    if is_nil(existing_changeset.errors[:start_time]) and !is_nil(existing_changeset.changes[:start_time]) do
      new_start_time = Changeset.get_field(existing_changeset, field)
      current_time_after_a_month = Date.now |> Date.shift(months: 1)
      valid = TimexHelper.compare(current_time_after_a_month, new_start_time)
      if !valid, do: existing_changeset = Changeset.add_error(existing_changeset, field, "should be less than a month")
    end
    existing_changeset
  end

  defp validate_single_update_of_status(existing_changeset) do
    id = get_field(existing_changeset, :id)
    if !is_nil(id) and is_nil(existing_changeset.errors[:interview_status_id]) do
      interview = id |> retrieve_interview
      if !is_nil(interview) and !is_nil(interview.interview_status_id), do: existing_changeset = add_error(existing_changeset, :interview_status, "Feedback has already been entered")
    end
    existing_changeset
  end

  def add_signup_eligibity_for(interviews, panelist_login_name, panelist_experience, panelist_role) do
    sign_up_data_container = SignUpEvaluator.populate_sign_up_data_container(panelist_login_name, Decimal.new(panelist_experience), panelist_role)
    role = sign_up_data_container.panelist_role
    interview_type_specfic_criteria = InterviewType.get_type_specific_panelists
    Enum.reduce(interviews, [], fn(interview, acc) ->
      if __MODULE__.is_visible(role, panelist_login_name, interview, interview_type_specfic_criteria),do: acc = acc ++ [__MODULE__.put_sign_up_status(sign_up_data_container, interview)]
      acc
    end)
  end

  def is_visible(panelist_role, panelist_login_name, interview, interview_type_specfic_criteria) do
    (InterviewTypeRelativeEvaluator.is_interview_type_with_specific_panelists(interview, interview_type_specfic_criteria)
      and InterviewTypeRelativeEvaluator.is_allowed_panelist(interview, interview_type_specfic_criteria, panelist_login_name))
    or panelist_role == nil
    or interview.candidate.role_id == panelist_role.id
  end

  def put_sign_up_status(sign_up_data_container, interview) do
    sign_up_evaluation_status = SignUpEvaluator.evaluate(sign_up_data_container, interview)
    interview = Map.put(interview, :signup_error, "")
    if !sign_up_evaluation_status.valid? do
      {_, error} = sign_up_evaluation_status.errors |> List.first
      interview = Map.put(interview, :signup_error, error)
    end
    Map.put(interview, :signup, sign_up_evaluation_status.valid?)
  end

  @lint [{Credo.Check.Refactor.ABCSize, false}, {Credo.Check.Refactor.CyclomaticComplexity, false}]
  def validate_with_other_rounds(existing_changeset, interview_type \\ :empty) do
    if existing_changeset.valid? do
      new_start_time = Changeset.get_field(existing_changeset, :start_time)
      new_end_time = Changeset.get_field(existing_changeset, :end_time)
      candidate_id = Changeset.get_field(existing_changeset, :candidate_id)
      interview_id = Changeset.get_field(existing_changeset, :id)
      current_priority = get_current_priority(existing_changeset, interview_type)
      previous_interview = get_interview(candidate_id, current_priority - 1)
      next_interview = get_interview(candidate_id, current_priority + 1)
      interview_with_same_priority = case interview_id do
        nil -> get_interview(candidate_id, current_priority)
        _ -> get_interview(candidate_id, current_priority, interview_id)
      end

      # TODO: This can be made a lot simpler by just using
      # (1) (one array for interviews for all interview_types <= current priority - self) and from this find the latest one
      # (2) (one array for interviews for all interview_types >= current priority - self) and from this find the earliest one
      # (3) check for overlap between results of (1) and (2) in case of non-nil value
      error_message = ""
      result = case {previous_interview, next_interview, interview_with_same_priority} do
        {nil, nil, nil} -> 1
        {nil, next_interview, nil} ->
          error_message = error_message <> "should be before #{next_interview.interview_type.name} atleast by 1 hour"
          TimexHelper.compare(next_interview.start_time, new_end_time)
        {previous_interview, nil, nil} ->
          error_message = error_message <> "should be after #{previous_interview.interview_type.name} atleast by 1 hour"
          TimexHelper.compare(new_start_time, previous_interview.end_time)
        {previous_interview, next_interview, nil} ->
          error_message = error_message <> "should be after #{previous_interview.interview_type.name} and before #{next_interview.interview_type.name} atleast by 1 hour"
          TimexHelper.compare(next_interview.start_time, new_end_time) && TimexHelper.compare(new_start_time, previous_interview.end_time)
        {nil, nil, interview_with_same_priority} ->
          error_message = error_message <> "before/after #{interview_with_same_priority.interview_type.name} atleast by 1 hour"
          (TimexHelper.compare(interview_with_same_priority.start_time, new_end_time) || TimexHelper.compare(new_start_time, interview_with_same_priority.end_time))
        {nil, next_interview, interview_with_same_priority} ->
          error_message = error_message <> "should be before #{next_interview.interview_type.name} and before/after #{interview_with_same_priority.interview_type.name} atleast by 1 hour"
          (TimexHelper.compare(interview_with_same_priority.start_time, new_end_time) || TimexHelper.compare(new_start_time, interview_with_same_priority.end_time)) &&
          TimexHelper.compare(next_interview.start_time, new_end_time)
        {previous_interview, nil, interview_with_same_priority} ->
          error_message = error_message <> "should be after #{previous_interview.interview_type.name} and before/after #{interview_with_same_priority.interview_type.name} atleast by 1 hour"
          (TimexHelper.compare(interview_with_same_priority.start_time, new_end_time) || TimexHelper.compare(new_start_time, interview_with_same_priority.end_time)) && TimexHelper.compare(new_start_time, previous_interview.end_time)
        {previous_interview, next_interview, interview_with_same_priority} ->
          error_message = error_message <> "should be after #{previous_interview.interview_type.name}, before #{next_interview.interview_type.name} and before/after #{interview_with_same_priority.interview_type.name} atleast by 1 hour"
          (TimexHelper.compare(interview_with_same_priority.start_time, new_end_time) || TimexHelper.compare(new_start_time, interview_with_same_priority.end_time)) && TimexHelper.compare(new_start_time, previous_interview.send_time) && TimexHelper.compare(next_interview.start_time, new_end_time)
      end

      if !result, do: existing_changeset = Changeset.add_error(existing_changeset, :start_time, error_message)
    end
    existing_changeset
  end

  defp get_current_priority(changes, interview_type) do
    case interview_type do
      :empty -> (Changeset.get_field(changes, :interview_type)).priority
      _ -> interview_type.priority
    end
  end

  def is_not_completed(model) do
    is_nil(model.interview_status_id)
  end

  def update_status(id, status_id) do
    interview = id |> retrieve_interview
    if !is_nil(interview) do
      [changeset(interview, %{"interview_status_id": status_id})] |> ChangesetManipulator.update
      if is_pass(status_id) do
        Repo.transaction fn ->
          delete_successive_interviews_and_panelists(interview.candidate_id, interview.start_time)
          Candidate.updateCandidateStatusAsPass(interview.candidate_id)
        end
      end
    end
  end

  defp is_pass(status_id) do
    status = (from i in InterviewStatus, where: i.name == ^PipelineStatus.pass) |> Repo.one
    !is_nil(status) and status.id == status_id
  end

  def delete_successive_interviews_and_panelists(candidate_id, start_time) do
    (from i in __MODULE__,
      where: i.candidate_id == ^candidate_id,
      where: (i.start_time > ^start_time)) |> Repo.delete_all
  end

  defp retrieve_interview(id) do
    __MODULE__ |> Repo.get(id)
  end

  defp get_interview(candidate_id, priority) do
    (from i in __MODULE__,
      join: it in assoc(i, :interview_type),
      preload: [:interview_type],
      where: i.candidate_id == ^candidate_id and
      it.priority == ^priority,
      order_by: i.start_time,
      limit: 1)
    |> Repo.one
  end

  defp get_interview(candidate_id, priority, interview_id) do
    (from i in __MODULE__,
      join: it in assoc(i, :interview_type),
      preload: [:interview_type],
      where: i.candidate_id == ^candidate_id and
      it.priority == ^priority and
      i.id != ^interview_id,
      order_by: i.start_time,
      limit: 1)
    |> Repo.one
  end

  def get_last_interview_status_for(current_candidate, last_interviews_data) do
    total_no_of_interview_types = Enum.count(InterviewType |> Repo.all)
    if Candidate.is_pipeline_closed(current_candidate) do
      result = Enum.filter(last_interviews_data, fn([candidate_id, _, _])-> current_candidate.id == candidate_id end)
      case result do
        [[candidate_id, last_interview_start_time, number_of_interviews]] ->
          status_id = (from i in __MODULE__,
          where: i.start_time == ^last_interview_start_time and
          i.candidate_id == ^candidate_id ,
          select: i.interview_status_id)
          |> Repo.one
          if !is_pass(status_id) and total_no_of_interview_types != number_of_interviews, do: status_id = nil
          status_id
        [] -> nil
      end
    end
  end

  def format(interview) do
    %{
      name: interview.interview_type.name,
      date: DateFormat.format!(interview.start_time, "%b-%d", :strftime)
    }
  end
end
