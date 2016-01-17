defmodule RecruitxBackend.Skill do
  use RecruitxBackend.Web, :model

  @derive {Poison.Encoder, only: [:id, :name]}
  schema "skills" do
    field :name, :string

    timestamps

    has_many :candidate_skills, RecruitxBackend.CandidateSkill
  end

  @required_fields ~w(name)
  @optional_fields ~w()

  def changeset(model, params \\ :empty) do
    model
    |> cast(params, @required_fields, @optional_fields)
    |> validate_length(:name, min: 1, max: 255)
    |> validate_format(:name, ~r/^[a-z]+[\sa-z]*$/i)
    |> unique_constraint(:name)
  end
end
