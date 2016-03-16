defmodule RecruitxBackend.InterviewSpec do
  use ESpec.Phoenix, model: RecruitxBackend.Interview

  alias RecruitxBackend.Candidate
  alias RecruitxBackend.Interview
  alias RecruitxBackend.InterviewPanelist
  alias RecruitxBackend.PipelineStatus
  alias RecruitxBackend.InterviewStatus
  alias RecruitxBackend.InterviewType
  alias RecruitxBackend.PipelineStatus
  alias RecruitxBackend.JSONErrorReason
  alias RecruitxBackend.Repo
  alias Timex.Date

  import Ecto.Query, only: [preload: 2]

  let :valid_attrs, do: fields_for(:interview)
  let :invalid_attrs, do: %{}

  context "valid changeset" do
    subject do: Interview.changeset(%Interview{}, valid_attrs)

    it do: should be_valid

    it "should be valid when interview status is present" do
      interview = Map.merge(valid_attrs, %{interview_status_id: create(:interview_status).id})

      result = Interview.changeset(%Interview{}, interview)

      expect(result) |> to(be_valid)
    end

    it "when interview date time is in the future" do
      future_interview = Map.merge(valid_attrs, %{start_time: (Date.now |> Date.shift(hours: 2))})

      result = Interview.changeset(%Interview{}, future_interview)

      expect(result) |> to(be_valid)
    end

    it "when end_time is not given and is replaced by default value" do
      result = Interview.changeset(%Interview{}, Map.delete(valid_attrs, :end_time))

      expect(result) |> to(be_valid)
      expect(result.changes.end_time) |> to(be(result.changes.start_time |> Date.shift(hours: 1)))
    end

    it "when end_time is given and is replaced by default value" do
      result = Interview.changeset(%Interview{}, valid_attrs)

      expect(result) |> to(be_valid)
      expect(result.changes.end_time) |> to(be(valid_attrs.start_time |> Date.shift(hours: 1)))
    end

    it "when start_time is updated  and end_time is re-calculated" do
      new_start_time = Date.now |> Date.shift(hours: 2)
      attrs_new_start_time = Map.merge(valid_attrs, %{start_time: new_start_time})
      result = Interview.changeset(%Interview{}, attrs_new_start_time)

      expect(result) |> to(be_valid)
      expect(result.changes.end_time) |> to(be(new_start_time |> Date.shift(hours: 1)))
    end
  end

  context "invalid changeset" do
    subject do: Interview.changeset(%Interview{}, invalid_attrs)

    it do: should_not be_valid
    it do: should have_errors([candidate_id: "can't be blank", interview_type_id: "can't be blank"])

    it "when candidate id is nil" do
      interview_with_candidate_id_nil = Map.merge(valid_attrs, %{candidate_id: nil})

      result = Interview.changeset(%Interview{}, interview_with_candidate_id_nil)

      expect(result) |> to(have_errors(candidate_id: "can't be blank"))
    end

    it "when candidate id is not present" do
      interview_with_no_candidate_id = Map.delete(valid_attrs, :candidate_id)

      result = Interview.changeset(%Interview{}, interview_with_no_candidate_id)

      expect(result) |> to(have_errors(candidate_id: "can't be blank"))
    end

    it "when interview_type id is nil" do
      interview_with_interview_id_nil = Map.merge(valid_attrs, %{interview_type_id: nil})

      result = Interview.changeset(%Interview{}, interview_with_interview_id_nil)

      expect(result) |> to(have_errors(interview_type_id: "can't be blank"))
    end

    it "when interview id is not present" do
      interview_with_no_interview_id = Map.delete(valid_attrs, :interview_type_id)

      result = Interview.changeset(%Interview{}, interview_with_no_interview_id)

      expect(result) |> to(have_errors(interview_type_id: "can't be blank"))
    end

    it "when interview date time is nil" do
      interview_with_start_time_nil = Map.merge(valid_attrs, %{start_time: nil})

      result = Interview.changeset(%Interview{}, interview_with_start_time_nil)

      expect(result) |> to(have_errors(start_time: "can't be blank"))
    end

    it "when interview date time is not present" do
      interview_with_no_start_time = Map.delete(valid_attrs, :start_time)

      result = Interview.changeset(%Interview{}, interview_with_no_start_time)

      expect(result) |> to(have_errors(start_time: "can't be blank"))
    end

    it "when interview date time is invalid" do
      interview_with_invalid_start_time = Map.merge(valid_attrs, %{start_time: "invalid"})

      result = Interview.changeset(%Interview{}, interview_with_invalid_start_time)

      expect(result) |> to(have_errors(start_time: "is invalid"))
    end

    it "when interview date time is in the past" do
      past_interview = Map.merge(valid_attrs, %{start_time: (Date.now |> Date.shift(hours: -2))})

      result = Interview.changeset(%Interview{}, past_interview)

      expect(result) |> to(have_errors(start_time: "should be in the future"))
    end

    it "when interview id and date time are invalid" do
      invalid_interview = Map.merge(valid_attrs, %{interview_type_id: 1.2, start_time: "invalid"})

      result = Interview.changeset(%Interview{}, invalid_interview)

      expect(result) |> to(have_errors([interview_type_id: "is invalid", start_time: "is invalid"]))
    end
  end

  context "foreign key constraint" do
    it "when candidate id not present in candidates table" do
      # TODO: Not sure why Ectoo.max(Repo, Candidate, :id) is failing - need to investigate
      current_candidate_count = Ectoo.count(Repo, Candidate)
      candidate_id_not_present = current_candidate_count + 1
      interview_with_invalid_candidate_id = Map.merge(valid_attrs, %{candidate_id: candidate_id_not_present})

      changeset = Interview.changeset(%Interview{}, interview_with_invalid_candidate_id)

      {:error, error_changeset} = Repo.insert(changeset)
      expect(error_changeset) |> to(have_errors([candidate: "does not exist"]))
    end

    it "when interview id not present in interview_type table" do
      # TODO: Not sure why Ectoo.max(Repo, InterviewType, :id) is failing - need to investigate
      current_interview_type_count = Ectoo.count(Repo, InterviewType)
      interview_type_id_not_present = current_interview_type_count + 1
      interview_with_invalid_interview_id = Map.merge(valid_attrs, %{interview_type_id: interview_type_id_not_present})

      changeset = Interview.changeset(%Interview{},interview_with_invalid_interview_id)

      {:error, error_changeset} = Repo.insert(changeset)
      expect(error_changeset) |> to(have_errors([interview_type: "does not exist"]))
    end

    it "when interview_status not present in interview_status table" do
      interview_with_invalid_status_id = Map.merge(valid_attrs, %{interview_status_id: 0})

      changeset = Interview.changeset(%Interview{},interview_with_invalid_status_id)

      {:error, error_changeset} = Repo.insert(changeset)
      expect(error_changeset) |> to(have_errors([interview_status: "does not exist"]))
    end
  end

  context "unique_index constraint will fail" do
    it "when same interview is scheduled more than once for a candidate" do
      changeset = Interview.changeset(%Interview{}, valid_attrs)
      Repo.insert(changeset)

      {:error, error_changeset} = Repo.insert(changeset)
      expect(error_changeset) |> to(have_errors([interview_type_id: "has already been taken"]))
    end
  end

  context "on delete" do
    it "should not raise an exception when it has foreign key reference in other tables" do
      interview = create(:interview)
      create(:interview_panelist, interview_id: interview.id)

      delete = fn -> Repo.delete!(interview) end

      expect(delete).to_not raise_exception(Ecto.ConstraintError)
    end

    it "should not raise an exception when it has no foreign key references in other tables" do
      interview = create(:interview)

      delete = fn ->  Repo.delete!(interview) end

      expect(delete).to_not raise_exception(Ecto.ConstraintError)
    end
  end

  context "desc_order" do
    before do: Repo.delete_all(Interview)
    it "should sort by descending order of start time" do
      now = Date.now
      interview_with_start_date1 = create(:interview, start_time: now |> Date.shift(days: 1))
      interview_with_start_date2 = create(:interview, start_time: now |> Date.shift(days: 3))
      interview_with_start_date3 = create(:interview, start_time: now |> Date.shift(days: -2))
      interview_with_start_date4 = create(:interview, start_time: now |> Date.shift(days: -5))

      [interview1, interview2, interview3, interview4] = Interview |> Interview.descending_order |> Repo.all

      expect(interview1.start_time) |> to(eq(interview_with_start_date2.start_time))
      expect(interview2.start_time) |> to(eq(interview_with_start_date1.start_time))
      expect(interview3.start_time) |> to(eq(interview_with_start_date3.start_time))
      expect(interview4.start_time) |> to(eq(interview_with_start_date4.start_time))
    end

    it "should tie-break on id for the same start time" do
      now = Date.now
      interview_with_start_date1 = create(:interview, start_time: now |> Date.shift(days: 1), id: 1)
      interview_with_same_start_date1 = create(:interview, start_time: now |> Date.shift(days: 1), id: interview_with_start_date1.id + 1)
      interview_with_start_date2 = create(:interview, start_time: now |> Date.shift(days: 2))

      [interview1, interview2, interview3] = Interview |> Interview.descending_order |> Repo.all

      expect(interview1.start_time) |> to(eq(interview_with_start_date2.start_time))
      expect(interview2.start_time) |> to(eq(interview_with_same_start_date1.start_time))
      expect(interview3.start_time) |> to(eq(interview_with_start_date1.start_time))
    end
  end

  context "default_order" do
    before do: Repo.delete_all(Interview)

    it "should sort by ascending order of start time" do
      now = Date.now
      interview_with_start_date1 = create(:interview, start_time: now |> Date.shift(days: 1))
      interview_with_start_date2 = create(:interview, start_time: now |> Date.shift(days: 3))
      interview_with_start_date3 = create(:interview, start_time: now |> Date.shift(days: -2))
      interview_with_start_date4 = create(:interview, start_time: now |> Date.shift(days: -5))

      [interview1, interview2, interview3, interview4] = Interview |> Interview.default_order |> Repo.all

      expect(interview1.start_time) |> to(eq(interview_with_start_date4.start_time))
      expect(interview2.start_time) |> to(eq(interview_with_start_date3.start_time))
      expect(interview3.start_time) |> to(eq(interview_with_start_date1.start_time))
      expect(interview4.start_time) |> to(eq(interview_with_start_date2.start_time))
    end

    it "should tie-break on id for the same start time" do
      now = Date.now
      interview_with_start_date1 = create(:interview, start_time: now |> Date.shift(days: 1), id: 1)
      interview_with_same_start_date1 = create(:interview, start_time: now |> Date.shift(days: 1), id: interview_with_start_date1.id + 1)
      interview_with_start_date2 = create(:interview, start_time: now |> Date.shift(days: 2))

      [interview1, interview2, interview3] = Interview |> Interview.default_order |> Repo.all

      expect(interview1.start_time) |> to(eq(interview_with_start_date1.start_time))
      expect(interview2.start_time) |> to(eq(interview_with_same_start_date1.start_time))
      expect(interview3.start_time) |> to(eq(interview_with_start_date2.start_time))
    end
  end

  describe "get_interviews_with_associated_data" do
    it "should return interviews of candidates" do
      Repo.delete_all(InterviewPanelist)
      Repo.delete_all(Interview)
      interview = create(:interview)
      candidate = Candidate |> preload(:candidate_skills)|> Repo.get(interview.candidate_id)

      actual_interview = Interview.get_interviews_with_associated_data |> Repo.one

      expect(actual_interview.candidate) |> to(be(candidate))
      expect(actual_interview.id) |> to(be(interview.id))
      expect(actual_interview.start_time) |> to(be(interview.start_time))
    end

    it "should return empty array when there no interviews" do
      Repo.delete_all(Interview)

      actual_interview_array = Interview.get_interviews_with_associated_data |> Repo.all

      expect(actual_interview_array) |> to(be([]))
    end
  end

  describe "update_status" do
    it "should not update interview when status is already entered" do
      interview = create(:interview)
      interview_status = create(:interview_status)
      Interview.update_status(interview.id, interview_status.id)

      update = fn ->  Interview.update_status(interview.id, 0) end

      expected_error = {:changeset_error, [%JSONErrorReason{field_name: :interview_status, reason: "Feedback has already been entered"}]}
      expect update |> to(throw_term expected_error)
    end

    it "should not update interview when status is invalid" do
      interview = create(:interview)
      update = fn ->  Interview.update_status(interview.id, 0) end
      expected_error = {:error, [%JSONErrorReason{field_name: :interview_status, reason: "does not exist"}]}

      expect update |> to(throw_term expected_error)
    end

    it "should update status and not delete other interviews,panelists for a candidate when status is not Pass" do
      interview = create(:interview)
      interview_status = create(:interview_status)
      interview_to_be_retained = create(:interview, candidate_id: interview.candidate_id, start_time: Date.now |> Date.shift(days: 7))
      panelists_to_be_retained = create(:interview_panelist, interview_id: interview_to_be_retained.id)

      Interview.update_status(interview.id, interview_status.id)

      updated_interview = Interview |> Repo.get(interview.id)
      expect(updated_interview.interview_status_id) |> to(be(interview_status.id))
      expect(!is_nil(Interview |> Repo.get(interview_to_be_retained.id))) |> to(be_true)
      expect(!is_nil(InterviewPanelist |> Repo.get(panelists_to_be_retained.id))) |> to(be_true)
    end

    it "should update status and delete future interviews,panelists when status is Pass" do
      Repo.delete_all InterviewStatus

      future_date = Date.now |> Date.shift(days: 7)
      interview = create(:interview, start_time: Date.now)
      future_interview = create(:interview, candidate_id: interview.candidate_id, start_time: future_date)
      future_panelist = create(:interview_panelist, interview_id: future_interview.id)
      interview_status = create(:interview_status, name: PipelineStatus.pass)
      pass_id = PipelineStatus.retrieve_by_name(PipelineStatus.pass).id

      Interview.update_status(interview.id, interview_status.id)

      updated_interview = Interview |> Repo.get(interview.id)
      updated_candidate = Candidate |> Repo.get(interview.candidate_id)
      expect(updated_candidate.pipeline_status_id) |> to(be(pass_id))
      expect(updated_interview.interview_status_id) |> to(be(interview_status.id))
      expect(Interview |> Repo.get(future_interview.id)) |> to(be_nil)
      expect(InterviewPanelist |> Repo.get(future_panelist.id)) |> to(be_nil)
    end

    it "should update status and not delete past interviews,panelists when status is Pass" do
      Repo.delete_all InterviewStatus

      past_date = Date.now |> Date.shift(days: -7)
      interview = create(:interview, start_time: Date.now)
      interview_to_be_retained = create(:interview, candidate_id: interview.candidate_id, start_time: past_date)
      panelists_to_be_retained = create(:interview_panelist, interview_id: interview_to_be_retained.id)
      interview_status = create(:interview_status, name: PipelineStatus.pass)
      pass_id = PipelineStatus.retrieve_by_name(PipelineStatus.pass).id

      Interview.update_status(interview.id, interview_status.id)

      updated_interview = Interview |> Repo.get(interview.id)
      updated_candidate = Candidate |> Repo.get(interview.candidate_id)
      expect(updated_candidate.pipeline_status_id) |> to(be(pass_id))
      expect(updated_interview.interview_status_id) |> to(be(interview_status.id))
      expect(!is_nil(Interview |> Repo.get(interview_to_be_retained.id))) |> to(be_true)
      expect(!is_nil(InterviewPanelist |> Repo.get(panelists_to_be_retained.id))) |> to(be_true)
    end

    it "should update status when status is Pass and there are no successive rounds" do
      Repo.delete_all InterviewStatus

      interview = create(:interview)
      interview_status = create(:interview_status, name: PipelineStatus.pass)
      pass_id = PipelineStatus.retrieve_by_name(PipelineStatus.pass).id

      Interview.update_status(interview.id, interview_status.id)

      updated_interview = Interview |> Repo.get(interview.id)
      updated_candidate = Candidate |> Repo.get(interview.candidate_id)
      expect(updated_candidate.pipeline_status_id) |> to(be(pass_id))
      expect(updated_interview.interview_status_id) |> to(be(interview_status.id))
    end
  end

  describe "get_last_completed_rounds_start_time_for_candidate" do
    it "should return the minimum possible date if no interviews are there for a candidate" do
      candidate = create(:candidate)
      expected_value = Date.set(Date.epoch, date: {0, 0, 1})

      actual_value = Interview.get_last_completed_rounds_start_time_for(candidate.id)

      expect(actual_value) |> to(be(expected_value))
    end

    it "should return the minimum possible date if all interviews are with status_id as nil for a candidate" do
      interview1 = create(:interview)
      create(:interview, candidate_id: interview1.candidate_id)
      candidate = Candidate |> Repo.get(interview1.candidate_id)
      expected_value = Date.set(Date.epoch, date: {0, 0, 1})

      actual_value = Interview.get_last_completed_rounds_start_time_for(candidate.id)

      expect(actual_value) |> to(be(expected_value))
    end

    it "should return the start date of a interview if candidate have one interview with status_id as not nil" do
      interview_status = create(:interview_status)
      interview = create(:interview, interview_status_id: interview_status.id)
      candidate = Candidate |> Repo.get(interview.candidate_id)
      expected_value = interview.start_time

      actual_value = Interview.get_last_completed_rounds_start_time_for(candidate.id)

      expect(actual_value) |> to(be(expected_value))
    end

    it "should return the maximum start date of a interview with if candidate have more than one interview with status_id as not nil" do
      now = Date.now
      interview_status = create(:interview_status)
      interview1 = create(:interview, interview_status_id: interview_status.id, start_time: now)
      interview2 = create(:interview, interview_status_id: interview_status.id, start_time: now |> Date.shift(hours: 1), candidate_id: interview1.candidate_id)
      candidate = Candidate |> Repo.get(interview2.candidate_id)
      expected_value = interview2.start_time

      actual_value = Interview.get_last_completed_rounds_start_time_for(candidate.id)

      expect(actual_value) |> to(be(expected_value))
    end
  end

  describe "validation for updating the interview schedule" do
    let :tomorrow, do: Date.now() |> Date.shift(days: 1)
    let :candidate, do: create(:candidate)
    let :code_pairing_interview_type, do: create(:interview_type, priority: 1, name: "CP")
    let :technical_one_interview_type, do: create(:interview_type, priority: 2, name: "T1")
    let :technical_two_interview_type, do: create(:interview_type, priority: 3, name: "T2")
    let :leadership_interview_type, do: create(:interview_type, priority: 4, name: "LD")
    let :p3_interview_type, do: create(:interview_type, priority: 4, name: "Pthree")

    it "should not allow interview with less priority to happen before interview with high priority" do
      code_pairing = create(:interview, interview_type_id: code_pairing_interview_type.id, candidate_id: candidate.id, start_time: tomorrow)
      create(:interview, interview_type_id: technical_one_interview_type.id, candidate_id: candidate.id, start_time: tomorrow |> Date.shift(hours: 2))

      changeset = Interview.changeset(code_pairing |> Repo.preload(:interview_type), %{"start_time" => tomorrow |> Date.shift(hours: 1.01)})
      changeset = Interview.validate_with_other_rounds(changeset)

      expect changeset.errors[:start_time] |> to(be("should be before T1 atleast by 1 hour"))
    end

    it "should not allow interview with high priority to happen after interview with low priority" do
      create(:interview, interview_type_id: code_pairing_interview_type.id, candidate_id: candidate.id, start_time: tomorrow, end_time: tomorrow |> Date.shift(hours: 1))
      technical_one = create(:interview, interview_type_id: technical_one_interview_type.id, candidate_id: candidate.id, start_time: tomorrow |> Date.shift(hours: 2))

      changeset = Interview.changeset(technical_one |> Repo.preload(:interview_type), %{"start_time" => tomorrow |> Date.shift(hours: -1.01)})
      changeset = Interview.validate_with_other_rounds(changeset)

      expect changeset.errors[:start_time] |> to(be("should be after CP atleast by 1 hour"))
    end

    it "should not allow interview to be scheduled after interview with high priority and before interview with low priority" do
      create(:interview, interview_type_id: code_pairing_interview_type.id, candidate_id: candidate.id, start_time: tomorrow)
      technical_one = create(:interview, interview_type_id: technical_one_interview_type.id, candidate_id: candidate.id, start_time: tomorrow |> Date.shift(hours: 1))
      create(:interview, interview_type_id: technical_two_interview_type.id, candidate_id: candidate.id, start_time: tomorrow
      |> Date.shift(hours: 1.5))

      changeset = Interview.changeset(technical_one |> Repo.preload(:interview_type), %{"start_time" => tomorrow |> Date.shift(hours: 0.75)})
      changeset = Interview.validate_with_other_rounds(changeset)

      expect changeset.errors[:start_time] |> to(be("should be after CP and before T2 atleast by 1 hour"))
    end

    it "should allow interview with high priority to happen after interview with low priority" do
      create(:interview, interview_type_id: code_pairing_interview_type.id, candidate_id: candidate.id, start_time: tomorrow)
      technical_one = create(:interview, interview_type_id: technical_one_interview_type.id, candidate_id: candidate.id, start_time: tomorrow
      |> Date.shift(hours: 2))

      changeset = Interview.changeset(technical_one |> Repo.preload(:interview_type), %{"start_time" => tomorrow |> Date.shift(days: 2)})
      changeset = Interview.validate_with_other_rounds(changeset)

      expect changeset.errors[:start_time] |> to(be(nil))
    end

    it "should allow interview with low priority to happen before interview with high priority" do
      code_pairing = create(:interview, interview_type_id: code_pairing_interview_type.id, candidate_id: candidate.id, start_time: tomorrow)
      create(:interview, interview_type_id: technical_one_interview_type.id, candidate_id: candidate.id, start_time: tomorrow
      |> Date.shift(hours: 4))

      changeset = Interview.changeset(code_pairing |> Repo.preload(:interview_type), %{"start_time" => tomorrow |> Date.shift(hours: -2)})
      changeset = Interview.validate_with_other_rounds(changeset)

      expect changeset.errors[:start_time] |> to(be(nil))
    end

    it "should allow interview with lowest priority to be modified without any constraint" do
      code_pairing = create(:interview, interview_type_id: code_pairing_interview_type.id, candidate_id: candidate.id, start_time: tomorrow)

      changeset = Interview.changeset(code_pairing |> Repo.preload(:interview_type), %{"start_time" => tomorrow |> Date.shift(hours: -2)})
      changeset = Interview.validate_with_other_rounds(changeset)

      expect changeset.errors[:start_time] |> to(be(nil))
    end

    describe "comparison with interviews of same priority based on start_time" do
      before do
        create(:interview, interview_type_id: technical_one_interview_type.id, candidate_id: candidate.id, start_time: tomorrow |> Date.shift(hours: 1))
      end

      let :technical_two, do: create(:interview, interview_type_id: technical_two_interview_type.id, candidate_id: candidate.id, start_time: tomorrow |> Date.shift(hours: 2))

      it "should use the interview with lowest start time for comparison" do
        create(:interview, interview_type_id: p3_interview_type.id, candidate_id: candidate.id, start_time: tomorrow
        |> Date.shift(hours: 3))
        create(:interview, interview_type_id: leadership_interview_type.id, candidate_id: candidate.id, start_time: tomorrow
        |> Date.shift(hours: 6))

        changeset = Interview.changeset(technical_two |> Repo.preload(:interview_type), %{"start_time" => tomorrow |> Date.shift(hours: 4)})
        changeset = Interview.validate_with_other_rounds(changeset)

        expect changeset.errors[:start_time] |> to(be("should be after T1 and before Pthree atleast by 1 hour"))
      end

      it "should use the interview with lowest start time for comparison" do
        create(:interview, interview_type_id: p3_interview_type.id, candidate_id: candidate.id, start_time: tomorrow
        |> Date.shift(hours: 6))
        create(:interview, interview_type_id: leadership_interview_type.id, candidate_id: candidate.id, start_time: tomorrow
        |> Date.shift(hours: 3))

        changeset = Interview.changeset(technical_two |> Repo.preload(:interview_type), %{"start_time" => tomorrow |> Date.shift(hours: 4)})
        changeset = Interview.validate_with_other_rounds(changeset)

        expect changeset.errors[:start_time] |> to(be("should be after T1 and before LD atleast by 1 hour"))
      end
    end

    describe "comparison with interviews of same priority" do
      before do
        create(:interview, interview_type_id: technical_two_interview_type.id, candidate_id: candidate.id, start_time: tomorrow |> Date.shift(hours: 2))
      end

      it "should return nil when there is no clash with same priority round" do
      p3 = create(:interview, interview_type_id: p3_interview_type.id, candidate_id: candidate.id, start_time: tomorrow
      |> Date.shift(hours: 6))
      create(:interview, interview_type_id: leadership_interview_type.id, candidate_id: candidate.id, start_time: tomorrow
      |> Date.shift(hours: 3))

      changeset = Interview.changeset(p3 |> Repo.preload(:interview_type), %{"start_time" => tomorrow |> Date.shift(hours: 4)})
      changeset = Interview.validate_with_other_rounds(changeset)

      expect changeset.errors[:start_time] |> to(be(nil))
    end

      it "should return error message when there is clash with same priority round" do
        p3 = create(:interview, interview_type_id: p3_interview_type.id, candidate_id: candidate.id, start_time: tomorrow |> Date.shift(hours: 6), end_time: tomorrow |> Date.shift(hours: 7))
        create(:interview, interview_type_id: leadership_interview_type.id, candidate_id: candidate.id, start_time: tomorrow |> Date.shift(hours: 3), end_time: tomorrow |> Date.shift(hours: 4))

        changeset = Interview.changeset(p3 |> Repo.preload(:interview_type), %{"start_time" => tomorrow |> Date.shift(hours: 2.1)})
        changeset = Interview.validate_with_other_rounds(changeset)

        expect changeset.errors[:start_time] |> to(be("should be after T2 and before/after LD atleast by 1 hour"))
      end
    end
  end

  context "get_candidates_with_all_rounds_completed" do
    it "should return all candidates who have completed no of rounds with start_time of last interview" do
      Repo.delete_all Candidate
      Repo.delete_all InterviewType
      interview1 = create(:interview, start_time: Date.now)
      interview2 = create(:interview, candidate_id: interview1.candidate_id, start_time: Date.now |> Date.shift(hours: 1))

      [[candidate_id, last_interview_start_time, completed_rounds]] = (Interview.get_candidates_with_all_rounds_completed) |> Repo.all

      expect(candidate_id) |> to(be(interview2.candidate_id))
      expect(Date.from(last_interview_start_time)) |> to(be(interview2.start_time))
      expect(completed_rounds) |> to(be(2))
    end

    it "should return [] when candidate has no interview rounds" do
      Repo.delete_all Candidate
      Repo.delete_all InterviewType

      create(:candidate)

      result = (Interview.get_candidates_with_all_rounds_completed) |> Repo.all
      expect(result) |> to(be([]))
    end
  end

  context "get_last_interview_status_for" do
    it "should add status of last interview if pipeline is closed and candidate has finished all rounds" do
      Repo.delete_all Candidate
      Repo.delete_all InterviewType

      interview_type1 = create(:interview_type)
      interview_type2 = create(:interview_type)
      candidate = create(:candidate, pipeline_status_id: PipelineStatus.retrieve_by_name(PipelineStatus.closed).id)
      interview_data1 = fields_for(:interview, candidate_id: candidate.id, interview_type_id: interview_type1.id, start_time: Date.now)
      interview_data2 = fields_for(:interview,
        candidate_id: candidate.id,
        interview_type_id: interview_type2.id,
        interview_status_id: create(:interview_status).id,
        start_time: Date.now |> Date.shift(hours: 1))
      total_no_of_interview_types = Enum.count(Repo.all(InterviewType))
      Repo.insert(Interview.changeset(%Interview{}, interview_data1))
      Repo.insert(Interview.changeset(%Interview{}, interview_data2))

      last_status = Interview.get_last_interview_status_for(candidate, [[candidate.id, interview_data2.start_time, total_no_of_interview_types]])

      expect(last_status) |> to(be(interview_data2.interview_status_id))
    end

    it "should add status of last interview if pipeline is closed and if that last interview is pass" do
      Repo.delete_all Candidate
      Repo.delete_all InterviewType

      pass_id = InterviewStatus.retrieve_by_name("Pass").id
      interview_type1 = create(:interview_type)
      interview_type2 = create(:interview_type)
      candidate = create(:candidate, pipeline_status_id: PipelineStatus.retrieve_by_name(PipelineStatus.closed).id)
      interview_data1 = fields_for(:interview, candidate_id: candidate.id, interview_type_id: interview_type1.id, start_time: Date.now)
      interview_data2 = fields_for(:interview,
        candidate_id: candidate.id,
        interview_type_id: interview_type2.id,
        interview_status_id: pass_id,
        start_time: Date.now |> Date.shift(hours: 1))
      total_no_of_interview_types = Enum.count(Repo.all(InterviewType))
      Repo.insert(Interview.changeset(%Interview{}, interview_data1))
      Repo.insert(Interview.changeset(%Interview{}, interview_data2))

      last_status = Interview.get_last_interview_status_for(candidate, [[candidate.id, interview_data2.start_time, total_no_of_interview_types]])

      expect(last_status) |> to(be(interview_data2.interview_status_id))
    end

    it "should not add status of last interview if pipeline is open and candidate has finished all rounds" do
      Repo.delete_all Candidate
      Repo.delete_all InterviewType

      interview_type1 = create(:interview_type)
      interview_type2 = create(:interview_type)
      candidate = create(:candidate)
      interview_data1 = fields_for(:interview, candidate_id: candidate.id, interview_type_id: interview_type1.id, start_time: Date.now)
      interview_data2 = fields_for(:interview,
        candidate_id: candidate.id,
        interview_type_id: interview_type2.id,
        interview_status_id: create(:interview_status).id,
        start_time: Date.now |> Date.shift(hours: 1))
      total_no_of_interview_types = Enum.count(Repo.all(InterviewType))
      Repo.insert(Interview.changeset(%Interview{}, interview_data1))
      Repo.insert(Interview.changeset(%Interview{}, interview_data2))

      last_status = Interview.get_last_interview_status_for(candidate, [[candidate.id, interview_data2.start_time, total_no_of_interview_types]])

      expect(last_status) |> to(be(nil))
    end
  end

  context "should_less_than_a_month" do
    it "should insert error into changeset if start_time is more than a month" do
      interview = Map.merge(valid_attrs, %{start_time: Date.now |> Date.shift(days: 32)})

      result = Interview.changeset(%Interview{}, interview)
      expect(result) |> to(have_errors(start_time: "should be less than a month"))
    end

    it "should not insert error into changeset if start_time is less than a month" do
      interview = Map.merge(valid_attrs, %{start_time: Date.now})

      result = Interview.changeset(%Interview{}, interview)
      expect(result) |> to(be_valid)
    end
  end

  context "is_in_future" do
    it "should insert error into changeset if start_time is in past" do
      interview = Map.merge(valid_attrs, %{start_time: Date.now |> Date.shift(hours: -1)})

      result = Interview.changeset(%Interview{}, interview)
      expect(result) |> to(have_errors(start_time: "should be in the future"))
    end

    it "should not insert error into changeset if start_time is in future" do
      interview = Map.merge(valid_attrs, %{start_time: Date.now |> Date.shift(hours: 1)})

      result = Interview.changeset(%Interview{}, interview)
      expect(result) |> to(be_valid)
    end
  end
end
