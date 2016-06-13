defmodule RecruitxBackend.SlotCancellationNotification do
  import Ecto.Query, only: [preload: 2, from: 2, select: 3]

  alias RecruitxBackend.Repo
  alias RecruitxBackend.MailHelper
  alias RecruitxBackend.Panel
  alias Timex.DateFormat
  alias Timex.Date
  alias Timex.Timezone
  alias Swoosh.Templates

  def execute(slots_to_delete_query) do
    (from q in slots_to_delete_query,
    join: sp in assoc(q, :slot_panelists),
    preload: ([:role, :interview_type]),
    select: {q, sp})
    |> Repo.all
    |> deliver_mail_for_cancelled_slots
  end

  def deliver_mail_for_cancelled_slots([]), do: :ok

  def deliver_mail_for_cancelled_slots([{slot, slot_panelist} | rest]) do
    formatted_date = slot.start_time
    |> Date.from
    |> Timezone.convert("Asia/Kolkata")
    |> DateFormat.format!("%d/%m/%y %H:%M", :strftime)

    MailHelper.deliver %{
      subject: "[RecruitX] " <> slot.interview_type.name <> " on " <> formatted_date <> " is cancelled",
      to: [slot_panelist.panelist_login_name |> Panel.get_email_address],
      html_body: Templates.slot_cancellation_notification(slot.interview_type.name,
        formatted_date)
    }
    deliver_mail_for_cancelled_slots(rest)
  end
end