defmodule ESpec.Phoenix.Extend do
  def model do
    quote do
      alias RecruitxBackend.Repo
      import RecruitxBackend.Factory
    end
  end

  def controller do
    quote do
      alias RecruitxBackend.Repo
      import RecruitxBackend.Router.Helpers
      import RecruitxBackend.Factory
    end
  end

  def request do
    quote do
      alias RecruitxBackend.Repo
      import RecruitxBackend.Router.Helpers
      import RecruitxBackend.Factory
    end
  end

  def view do
    quote do
      import RecruitxBackend.Router.Helpers
      import RecruitxBackend.Factory
    end
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
