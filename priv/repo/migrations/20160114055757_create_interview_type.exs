defmodule RecruitxBackend.Repo.Migrations.CreateInterviewType do
  use Ecto.Migration

  alias RecruitxBackend.InterviewType
  alias RecruitxBackend.Repo

  def change do
    create table(:interview_types) do
      add :name, :string, null: false
      add :priority, :integer

      timestamps
    end

    execute "CREATE UNIQUE INDEX interview_types_name_index ON interview_types (UPPER(name));"

    flush

    Enum.map(%{"Code Pairing1" => 1,
               "Technical11" => 2,
               "Technical21" => 3,
               "Leadersh1ip" => 4,
               "P13" => 4}, fn {name_value, priority_value} ->
      Repo.insert!(%InterviewType{name: name_value, priority: priority_value})
    end)
  end
end