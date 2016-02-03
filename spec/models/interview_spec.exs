defmodule RecruitxBackend.InterviewSpec do
  use ESpec.Phoenix, model: RecruitxBackend.Interview

  alias RecruitxBackend.Candidate
  alias RecruitxBackend.Interview
  alias RecruitxBackend.InterviewType
  alias RecruitxBackend.InterviewPanelist
  alias RecruitxBackend.Repo

  let :valid_attrs, do: fields_for(:interview)
  let :invalid_attrs, do: %{}

  context "valid changeset" do
    subject do: Interview.changeset(%Interview{}, valid_attrs)

    it do: should be_valid
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
      interview_with_interview_date_time_nil = Map.merge(valid_attrs, %{start_time: nil})

      result = Interview.changeset(%Interview{}, interview_with_interview_date_time_nil)

      expect(result) |> to(have_errors(start_time: "can't be blank"))
    end

    it "when interview date time is not present" do
      interview_with_no_interview_date_time = Map.delete(valid_attrs, :start_time)

      result = Interview.changeset(%Interview{}, interview_with_no_interview_date_time)

      expect(result) |> to(have_errors(start_time: "can't be blank"))
    end

    it "when interview date time is invalid" do
      interview_with_candidate_id_nil = Map.merge(valid_attrs, %{start_time: "invalid"})

      result = Interview.changeset(%Interview{}, interview_with_candidate_id_nil)

      expect(result) |> to(have_errors(start_time: "is invalid"))
    end

    it "when interview id and date time are  invalid" do
      interview_with_candidate_id_nil = Map.merge(valid_attrs, %{interview_type_id: 1.2, start_time: "invalid"})

      result = Interview.changeset(%Interview{}, interview_with_candidate_id_nil)

      expect(result) |> to(have_errors([interview_type_id: "is invalid", start_time: "is invalid"]))
    end
  end

  context "foreign key constraint" do
    it "when candidate id not present in candidates table" do
      # TODO: Not sure why Ectoo.max(Repo, Candidate, :id) is failing - need to investigate
      current_candidate_count = Ectoo.count(Repo, Candidate)
      candidate_id_not_present = current_candidate_count + 1
      # TODO: Use factory
      interview_with_invalid_candidate_id = Map.merge(valid_attrs, %{candidate_id: candidate_id_not_present})

      changeset = Interview.changeset(%Interview{}, interview_with_invalid_candidate_id)

      {:error, error_changeset} = Repo.insert(changeset)
      expect(error_changeset) |> to(have_errors([candidate: "does not exist"]))
    end

    it "when interview id not present in interview_type table" do
      # TODO: Not sure why Ectoo.max(Repo, InterviewType, :id) is failing - need to investigate
      current_interview_type_count = Ectoo.count(Repo, InterviewType)
      # TODO: Use factory
      interview_type_id_not_present = current_interview_type_count + 1
      interview_with_invalid_interview_id = Map.merge(valid_attrs, %{interview_type_id: interview_type_id_not_present})

      changeset = Interview.changeset(%Interview{},interview_with_invalid_interview_id)

      {:error, error_changeset} = Repo.insert(changeset)
      expect(error_changeset) |> to(have_errors([interview_type: "does not exist"]))
    end
  end

  context "unique_index constraint will fail" do
    it "when same interview is scheduled more than once for a candidate" do
      # TODO: Use factory
      changeset = Interview.changeset(%Interview{}, valid_attrs)
      Repo.insert(changeset)

      {:error, error_changeset} = Repo.insert(changeset)
      expect(error_changeset) |> to(have_errors([interview_type_id: "has already been taken"]))
    end
  end

  context "on delete" do
    it "should raise an exception when it has foreign key reference in other tables" do
      interview = create(:interview)
      create(:interview_panelist, interview_id: interview.id)

      delete = fn -> Repo.delete!(interview) end

      expect(delete).to raise_exception(Ecto.ConstraintError)
    end

    it "should not raise an exception when it has no foreign key references in other tables" do
      interview = create(:interview)

      delete = fn ->  Repo.delete!(interview) end

      expect(delete).to_not raise_exception(Ecto.ConstraintError)
    end
  end

  describe "query" do
    context "get_candidate_ids_interviewed_by" do
      before do:  Repo.delete_all(InterviewPanelist)

      it "should return no candidate_ids when none were interviewed by panelist" do
        candidate_ids = Repo.all Interview.get_candidate_ids_interviewed_by("dummy")

        expect(candidate_ids) |> to(be([]))
      end

      it "should return candidate_ids who were interviewed by panelist" do
        interview1 = create(:interview)
        interview2 = create(:interview)
        create(:interview_panelist, interview_id: interview1.id, panelist_login_name: "test")
        create(:interview_panelist, interview_id: interview2.id, panelist_login_name: "test")

        candidate_ids = Repo.all Interview.get_candidate_ids_interviewed_by("test")

        expect(Enum.sort(candidate_ids)) |> to(be([interview1.candidate_id, interview2.candidate_id]))

      end

      it "should not return candidate_ids who were not interviewed by panelist" do
        candidateInterviewed = create(:candidate)
        candidateNotInterviewed = create(:candidate)

        interview1 = create(:interview, candidate: candidateInterviewed, candidate_id: candidateInterviewed.id)
        interview2 = create(:interview, candidate: candidateNotInterviewed, candidate_id: candidateNotInterviewed.id)

        create(:interview_panelist, interview_id: interview1.id, panelist_login_name: "test")
        create(:interview_panelist, interview_id: interview2.id, panelist_login_name: "dummy")

        candidate_ids = Repo.all Interview.get_candidate_ids_interviewed_by("test")

        expect(candidate_ids) |> to(be([interview1.candidate_id]))
      end
    end
  end
end
