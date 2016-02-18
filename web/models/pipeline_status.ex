defmodule RecruitxBackend.PipelineStatus do
  use RecruitxBackend.Web, :model

  alias RecruitxBackend.Candidate
  alias RecruitxBackend.Repo

  import Ecto.Query, only: [from: 2, where: 2]

  schema "pipeline_statuses" do
    field :name, :string

    timestamps

    has_many :candidates, Candidate
  end

  @required_fields ~w(name)
  @optional_fields ~w()

  def changeset(model, params) do
    model
    |> cast(params, @required_fields, @optional_fields)
    |> validate_length(:name, min: 1, max: 255)
    |> validate_format(:name, ~r/^[a-z]+[\sa-z]*$/i)
    |> unique_constraint(:name, name: :pipeline_statuses_name_index)
  end

  def retrieve_by_name(name) do
    (from ps in __MODULE__, where: ps.name == ^name) |> Repo.one
  end
end
