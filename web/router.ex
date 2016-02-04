defmodule RecruitxBackend.Router do
  use RecruitxBackend.Web, :router

  pipeline :api  do
    plug :accepts, ["json"]
  end

  scope "/", RecruitxBackend do
    pipe_through :api

    resources "/roles", RoleController, only: [:index]
    resources "/skills", SkillController, only: [:index]
    resources "/candidates", CandidateController, only: [:index, :create, :show]
    resources "/candidates/:id/interviews", InterviewController, only: [:index]
    resources "/interview_types", InterviewTypeController, only: [:index]
    resources "/interviews", InterviewController, only: [:index, :show]
    resources "/panelists", PanelistController, only: [:create, :show]
  end

  # Other scopes may use custom stacks.
  # scope "/api", RecruitxBackend do
  #   pipe_through :api
  # end
end
