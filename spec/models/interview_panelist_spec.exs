defmodule RecruitxBackend.InterviewPanelistSpec do
  use ESpec.Phoenix, model: RecruitxBackend.InterviewPanelist

  alias RecruitxBackend.Interview
  alias RecruitxBackend.InterviewPanelist
  alias RecruitxBackend.Repo
  alias Timex.Date

  let :valid_attrs, do: fields_for(:interview_panelist)
  let :invalid_attrs, do: %{}

  before do: Repo.delete_all(Interview)

  context "valid changeset" do
    subject do: InterviewPanelist.changeset(%InterviewPanelist{}, valid_attrs)

    it do: should be_valid

    it "should allow panelist to sign up if he has other interviews beyond time buffer of 2 hours" do
      interview_signed_up = create(:interview_panelist)
      signed_up_interview = Interview |> Repo.get(interview_signed_up.interview_id)
      new_interview = create(:interview, start_time: signed_up_interview.start_time |> Date.shift(hours: 3))

      changeset = InterviewPanelist.changeset(%InterviewPanelist{}, %{panelist_login_name: interview_signed_up.panelist_login_name, interview_id: new_interview.id})

      expect(changeset) |> to(be_valid)
    end

    it "should allow panelist to sign up if he has other interviews at exactly time buffer of 2 hours" do
      interview_signed_up = create(:interview_panelist)
      signed_up_interview = Interview |> Repo.get(interview_signed_up.interview_id)
      new_interview = create(:interview, start_time: signed_up_interview.start_time |> Date.shift(hours: 2))

      changeset = InterviewPanelist.changeset(%InterviewPanelist{}, %{panelist_login_name: interview_signed_up.panelist_login_name, interview_id: new_interview.id})

      expect(changeset) |> to(be_valid)
    end
  end

  context "invalid changeset" do
    subject do: InterviewPanelist.changeset(%InterviewPanelist{}, invalid_attrs)

    it do: should_not be_valid
    it do: should have_errors([panelist_login_name: "can't be blank", interview_id: "can't be blank"])

    it "should be invalid when panelist_login_name is an empty string" do
      with_empty_name = Map.merge(valid_attrs, %{panelist_login_name: ""})
      changeset = InterviewPanelist.changeset(%InterviewPanelist{}, with_empty_name)

      expect(changeset) |> to(have_errors([panelist_login_name: "has invalid format"]))
    end

    it "should be invalid when panelist_login_name is a blank string" do
      with_blank_name = Map.merge(valid_attrs, %{panelist_login_name: " "})
      changeset = InterviewPanelist.changeset(%InterviewPanelist{}, with_blank_name)

      expect(changeset) |> to(have_errors([panelist_login_name: "has invalid format"]))
    end

    it "should be invalid when panelist_login_name is nil" do
      with_nil_name = Map.merge(valid_attrs, %{panelist_login_name: nil})
      changeset = InterviewPanelist.changeset(%InterviewPanelist{}, with_nil_name)

      expect(changeset) |> to(have_errors([panelist_login_name: "can't be blank"]))
    end


    it "should be invalid when panelist_login_name starts with space" do
      with_nil_name = Map.merge(valid_attrs, %{panelist_login_name: " ab"})
      changeset = InterviewPanelist.changeset(%InterviewPanelist{}, with_nil_name)

      expect(changeset) |> to(have_errors([panelist_login_name: "has invalid format"]))
    end

    it "should be invalid when interview_id is an empty string" do
      with_empty_id = Map.merge(valid_attrs, %{interview_id: ""})
      changeset = InterviewPanelist.changeset(%InterviewPanelist{}, with_empty_id)

      expect(changeset) |> to(have_errors([interview_id: "is invalid"]))
    end

    it "should be invalid when interview_id is nil" do
      with_nil_id = Map.merge(valid_attrs, %{interview_id: nil})
      changeset = InterviewPanelist.changeset(%InterviewPanelist{}, with_nil_id)

      expect(changeset) |> to(have_errors([interview_id: "can't be blank"]))
    end

    it "should be invalid when max signups are already done" do
      interview = create(:interview)
      create(:interview_panelist, interview_id: interview.id)
      create(:interview_panelist, interview_id: interview.id)
      interview_panelist = fields_for(:interview_panelist, interview_id: interview.id)

      changeset = InterviewPanelist.changeset(%InterviewPanelist{}, interview_panelist)

      expect(changeset) |> to(have_errors([signup_count: "More than 2 signups are not allowed"]))
    end

    it "should be invalid when feedback is already entered" do
      interview = create(:interview, interview_status_id: create(:interview_status).id)
      interview_panelist = fields_for(:interview_panelist, interview_id: interview.id)

      changeset = InterviewPanelist.changeset(%InterviewPanelist{}, interview_panelist)

      expect(changeset) |> to(have_errors([signup: "Interview is already over!"]))
    end

    it "should be invalid when panelist has already done a previous interview for the candidate" do
      candidate = create(:candidate)
      interview1 = create(:interview, candidate_id: candidate.id)
      interview2 = create(:interview, candidate_id: candidate.id)

      create(:interview_panelist, interview_id: interview1.id, panelist_login_name: "test")
      interview_panelist = fields_for(:interview_panelist, interview_id: interview2.id, panelist_login_name: "test")

      changeset = InterviewPanelist.changeset(%InterviewPanelist{}, interview_panelist)

      expect(changeset) |> to(have_errors([signup: "You have already signed up an interview for this candidate"]))
    end

    it "should not allow panelist to sign up if he has another interview within time buffer of 2 hours" do
      interview_signed_up = create(:interview_panelist)
      signed_up_interview = Interview |> Repo.get(interview_signed_up.interview_id)
      new_interview = create(:interview, start_time: signed_up_interview.start_time |> Date.shift(hours: 1))

      changeset = InterviewPanelist.changeset(%InterviewPanelist{}, %{panelist_login_name: interview_signed_up.panelist_login_name, interview_id: new_interview.id})

      expect(changeset) |> to(have_errors([signup: "You are already signed up for another interview within 2 hours"]))
    end
  end

  context "unique_index constraint" do
    it "should not allow same panelist to be added more than once for same interview" do
      changeset = InterviewPanelist.changeset(%InterviewPanelist{}, valid_attrs)
      Repo.insert(changeset)

      {:error, error_changeset} = Repo.insert(changeset)
      expect(error_changeset) |> to(have_errors([panelist_login_name: "You have already signed up for this interview"]))
    end

    it "should allow same panelist to be added more than once for a different interview" do
      changeset = InterviewPanelist.changeset(%InterviewPanelist{}, valid_attrs)
      Repo.insert(changeset)
      signed_up_interview = Interview |> Repo.get(valid_attrs.interview_id)
      new_interview = create(:interview, start_time: signed_up_interview.start_time |> Date.shift(hours: 2))
      changeset = InterviewPanelist.changeset(%InterviewPanelist{}, Map.merge(valid_attrs, %{interview_id: new_interview.id}))

      {status, _} = Repo.insert(changeset)

      expect(status) |> to(eql(:ok))
    end
  end

  context "assoc constraint" do
    it "when candidate id not present in candidates table" do
      interview_id_not_present = -1
      with_invalid_interview_id = Map.merge(valid_attrs, %{interview_id: interview_id_not_present})

      changeset = InterviewPanelist.changeset(%InterviewPanelist{}, with_invalid_interview_id)

      {:error, error_changeset} = Repo.insert(changeset)
      expect(error_changeset) |> to(have_errors([interview: "Interview does not exist"]))
    end
  end

  describe "query" do
    context "get_signup_count_for_interview_id" do
      it "should return nil when there are no signups" do
        result = InterviewPanelist.get_signup_count_for_interview_id(-1) |> Repo.one

        expect(result) |> to(eql(nil))
      end

      it "should return 1 when there is a signup" do
        interview_panelist = create(:interview_panelist)
        result = InterviewPanelist.get_signup_count_for_interview_id(interview_panelist.interview_id) |> Repo.one

        expect(result) |> to(eql(1))
      end
    end

    context "get_interview_type_based_count_of_sign_ups" do
      it "should return {interview_id, count_of_signups, interview_type_id" do
        result = InterviewPanelist.get_interview_type_based_count_of_sign_ups |> Repo.all

        expect(result) |> to(eql([]))
      end

      it "should return {interview_id, count_of_signups, interview_type_id}" do
        interview = create(:interview)
        interview_panelist = create(:interview_panelist, interview_id: interview.id)
        [result] = InterviewPanelist.get_interview_type_based_count_of_sign_ups |> Repo.all
        %{"interview_id": interview_id,"signup_count": count_of_signups,"interview_type": type_id} = result
        expect(interview_id) |> to(eql(interview_panelist.interview_id))
        expect(count_of_signups) |> to(eql(1))
        expect(type_id) |> to(eql(interview.interview_type_id))
      end
    end
  end

  context "trigger check_signup_validity" do
    it "should raise exception when trying to insert more than 2 panelists for the same interview" do
      interview = create(:interview)
      create(:interview_panelist, interview_id: interview.id)
      create(:interview_panelist, interview_id: interview.id)

      create = fn -> create(:interview_panelist, interview_id: interview.id) end

      expect(create).to raise_exception(Elixir.Postgrex.Error, "ERROR (raise_exception): More than 2 sign-ups not allowed")
    end
  end
end
