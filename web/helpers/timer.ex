defmodule RecruitxBackend.Timer do

  alias Ecto.Changeset
  alias RecruitxBackend.TimexHelper

  def get_current_week_weekdays do
    %{starting: TimexHelper.beginning_of_week(TimexHelper.utc_now()), ending: TimexHelper.end_of_week(TimexHelper.utc_now()) |> TimexHelper.add(-2, :days)}
  end

  def get_current_week do
    %{starting: TimexHelper.beginning_of_week(TimexHelper.utc_now()), ending: TimexHelper.end_of_week(TimexHelper.utc_now())}
  end

  def get_previous_month do
    day_from_previous_month = TimexHelper.utc_now() |> TimexHelper.beginning_of_month |>  TimexHelper.add(-1, :days)
    %{starting: TimexHelper.beginning_of_month(day_from_previous_month), ending: TimexHelper.end_of_month(day_from_previous_month)}
  end

  def get_current_month do
    %{starting: TimexHelper.beginning_of_month(TimexHelper.utc_now()), ending: TimexHelper.end_of_month(TimexHelper.utc_now())}
  end

  def get_previous_quarter do
    day_from_previous_quarter = TimexHelper.utc_now() |> TimexHelper.beginning_of_quarter |> TimexHelper.add(-1, :days)
    %{starting: TimexHelper.beginning_of_quarter(day_from_previous_quarter), ending: TimexHelper.end_of_quarter(day_from_previous_quarter)}
  end

  def add_end_time(existing_changeset, duration_of_interview) do
    incoming_start_time = existing_changeset |> Changeset.get_field(:start_time)
    if is_nil(existing_changeset.errors[:start_time]) and !is_nil(existing_changeset.changes[:start_time]) do
      min_valid_end_time = incoming_start_time |> TimexHelper.add(duration_of_interview, :hours)
      existing_changeset = existing_changeset |> Changeset.put_change(:end_time, min_valid_end_time)
    end
    existing_changeset
  end

  def is_in_future(existing_changeset, field) do
    if is_nil(existing_changeset.errors[field]) and !is_nil(existing_changeset.changes[field]) do
      new_start_time = Changeset.get_field(existing_changeset, field)
      current_time = TimexHelper.add(TimexHelper.utc_now(), -5, :minutes)
      valid = TimexHelper.compare(new_start_time, current_time)
      if !valid, do: existing_changeset = Changeset.add_error(existing_changeset, field, "should be in the future")
    end
    existing_changeset
  end

  def is_after(%{valid?: true} = existing_changeset, end_date_field, start_date_field) do
    if is_nil(existing_changeset.errors[end_date_field]) and !is_nil(existing_changeset.changes[end_date_field]) do
      start_date = Changeset.get_field(existing_changeset, start_date_field)
      end_date = Changeset.get_field(existing_changeset, end_date_field)
      valid = TimexHelper.compare(end_date, start_date)
      if !valid, do: existing_changeset = Changeset.add_error(existing_changeset, end_date_field, "should be after start date")
    end
    existing_changeset
  end

  def is_after(existing_changeset, _end_date_field, _start_date_field), do: existing_changeset


  def is_less_than_a_month(existing_changeset, field) do
    if is_nil(existing_changeset.errors[field]) and !is_nil(existing_changeset.changes[field]) do
      new_start_time = Changeset.get_field(existing_changeset, field)
      current_time_after_a_month = TimexHelper.utc_now() |> TimexHelper.add(1, :months)
      valid = TimexHelper.compare(current_time_after_a_month, new_start_time)
      if !valid, do: existing_changeset = Changeset.add_error(existing_changeset, field, "should be less than a month")
    end
    existing_changeset
  end
end
