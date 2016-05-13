defmodule RecruitxBackend.TimerSpec do
  use ESpec.Phoenix, model: RecruitxBackend.Timer

  alias RecruitxBackend.Timer
  alias RecruitxBackend.Interview
  alias Ecto.Changeset
  alias Timex.Date

  @duration_of_interview 1

  describe "methods" do
    let :valid_params, do: fields_for(:interview)

    context "add_end_time" do
      it "should calculate and add end_time when incoming changeset is valid" do
        valid_changeset = Changeset.cast(%Interview{}, Map.delete(valid_params, :end_time), ~w(candidate_id interview_type_id start_time), ~w(interview_status_id))
        response = Timer.add_end_time(valid_changeset, @duration_of_interview)
        expected_end_time = valid_params.start_time |> Date.shift(hours: 1)
        expect(response.changes.end_time) |> to(be(expected_end_time))
      end

      it "should not calculate and add end_time when incoming changeset is valid" do
        invalid_changeset = Changeset.cast(%Interview{}, Map.delete(valid_params, :end_time), ~w(candidate_id interview_type_id), ~w(interview_status_id))
        response = Timer.add_end_time(invalid_changeset, @duration_of_interview)
        expect(fn -> response.changes.end_time end) |> to(raise_exception)
      end
    end

    context "is_in_future" do
      it "should validate and should not add error when incoming changeset's start_time is in future" do
        valid_changeset = Changeset.cast(%Interview{}, valid_params, ~w(candidate_id interview_type_id start_time), ~w(interview_status_id))
        response = Timer.is_in_future(valid_changeset, :start_time)
        expect(response.valid?) |> to(be(true))
      end

      it "should validate and should add error when incoming changeset's start_time is in future" do
        valid_params = Map.merge(Map.delete(valid_params, :start_time), %{start_time: Date.now |> Date.shift(hours: -1)})
        valid_changeset = Changeset.cast(%Interview{}, valid_params, ~w(candidate_id interview_type_id start_time), ~w(interview_status_id))
        response = Timer.is_in_future(valid_changeset, :start_time)
        expect(response.valid?) |> to(be(false))
        expect(response) |> to(have_errors(start_time: "should be in the future"))
      end
    end

    context "is_less_than_a_month" do
      it "should validate and should not add error when incoming changeset's start_time is less than a month" do
        valid_changeset = Changeset.cast(%Interview{}, valid_params, ~w(candidate_id interview_type_id start_time), ~w(interview_status_id))
        response = Timer.is_less_than_a_month(valid_changeset, :start_time)
        expect(response.valid?) |> to(be(true))
      end

      it "should validate and should add error when incoming changeset's start_time is after a month" do
        valid_params = Map.merge(Map.delete(valid_params, :start_time), %{start_time: Date.now |> Date.shift(months: 2)})
        valid_changeset = Changeset.cast(%Interview{}, valid_params, ~w(candidate_id interview_type_id start_time), ~w(interview_status_id))
        response = Timer.is_less_than_a_month(valid_changeset, :start_time)
        expect(response.valid?) |> to(be(false))
        expect(response) |> to(have_errors(start_time: "should be less than a month"))
      end
    end
  end
end