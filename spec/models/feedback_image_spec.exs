defmodule RecruitxBackend.FeedbackImageSpec do
  use ESpec.Phoenix, model: RecruitxBackend.FeedbackImage

  alias RecruitxBackend.FeedbackImage

  let :valid_attrs, do: fields_for(:feedback_image)
  let :invalid_attrs, do: %{}

  context "valid changeset" do
    subject do: FeedbackImage.changeset(%FeedbackImage{}, valid_attrs)

    it do: should be_valid
  end

  context "invalid changeset" do
    subject do: FeedbackImage.changeset(%FeedbackImage{}, invalid_attrs)

    it do: should_not be_valid
    it do: should have_errors([file_name: "can't be blank", interview_id: "can't be blank"])

    it "should be invalid when file_name is an empty string" do
      with_empty_name = Map.merge(valid_attrs, %{file_name: ""})
      changeset = FeedbackImage.changeset(%FeedbackImage{}, with_empty_name)

      expect(changeset) |> to(have_errors([file_name: "has invalid format"]))
    end

    it "should be invalid when file_name is a blank string" do
      with_blank_name = Map.merge(valid_attrs, %{file_name: " "})
      changeset = FeedbackImage.changeset(%FeedbackImage{}, with_blank_name)

      expect(changeset) |> to(have_errors([file_name: "has invalid format"]))
    end

    it "should be invalid when file_name starts with space" do
      with_nil_name = Map.merge(valid_attrs, %{file_name: " ab"})
      changeset = FeedbackImage.changeset(%FeedbackImage{}, with_nil_name)

      expect(changeset) |> to(have_errors([file_name: "has invalid format"]))
    end

    it "should be invalid when file_name is nil" do
      with_nil_name = Map.merge(valid_attrs, %{file_name: nil})
      changeset = FeedbackImage.changeset(%FeedbackImage{}, with_nil_name)

      expect(changeset) |> to(have_errors([file_name: "can't be blank"]))
    end

    it "should be invalid when interview_id is an empty string" do
      with_empty_id = Map.merge(valid_attrs, %{interview_id: ""})
      changeset = FeedbackImage.changeset(%FeedbackImage{}, with_empty_id)

      expect(changeset) |> to(have_errors([interview_id: "is invalid"]))
    end

    it "should be invalid when interview_id is nil" do
      with_nil_id = Map.merge(valid_attrs, %{interview_id: nil})
      changeset = FeedbackImage.changeset(%FeedbackImage{}, with_nil_id)

      expect(changeset) |> to(have_errors([interview_id: "can't be blank"]))
    end
  end

  context "assoc constraint" do
    it "when interview id not present in interviews table" do
      interview_id_not_present = -1
      with_invalid_interview_id = Map.merge(valid_attrs, %{interview_id: interview_id_not_present})

      changeset = FeedbackImage.changeset(%FeedbackImage{}, with_invalid_interview_id)

      {:error, error_changeset} = Repo.insert(changeset)
      expect(error_changeset) |> to(have_errors([interview: "does not exist"]))
    end
  end
end