defmodule RecruitxBackend.Role do
  use RecruitxBackend.Web, :model

  alias RecruitxBackend.Role

  schema "roles" do
    field :name, :string
    has_many :candidates, RecruitxBackend.Candidate

    timestamps
  end

  @required_fields ~w(name)
  @optional_fields ~w()

  def changeset(model, params \\ :empty) do
    model
    |> cast(params, @required_fields, @optional_fields)
    |> unique_constraint(:name)
    |> validate_length(:name, min: 1, max: 255)
  end
end