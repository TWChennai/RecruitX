defmodule RecruitxBackend.Repo.Migrations.AddNewSkills do
  use Ecto.Migration

  alias RecruitxBackend.Repo
  alias RecruitxBackend.Skill

  def change do
    Enum.each(["Selenium",
              "QTP",
              "CI",
              "Performance"], fn skill_value ->
      Repo.insert!(%Skill{name: skill_value})
    end)
  end
end
