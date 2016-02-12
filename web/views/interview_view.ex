defmodule RecruitxBackend.InterviewView do
  use RecruitxBackend.Web, :view

  alias Timex.DateFormat

  def render("index.json", %{interviews_with_signup: interviews}) do
    render_many(interviews, RecruitxBackend.InterviewView, "interview_with_signup.json")
  end

  def render("index.json", %{interviews: interviews}) do
    render_many(interviews, RecruitxBackend.InterviewView, "interview.json")
  end

  def render("show.json", %{interview: interview}) do
    render_one(interview, RecruitxBackend.InterviewView, "interview_with_panelists.json")
  end

  def render("missing_param_error.json", %{param: param}) do
    %{
      field: param,
      reason: "missing/empty required parameter"
    }
  end

  def render("interview_with_signup.json", %{interview: interview}) do
    %{
      id: interview.id,
      start_time: DateFormat.format!(interview.start_time, "%Y-%m-%dT%H:%M:%SZ", :strftime),
      interview_type_id: interview.interview_type_id,
      candidate: render_one(interview.candidate, RecruitxBackend.CandidateView, "candidate.json"),
      status_id: interview.interview_status_id,
      signup: interview.signup,
      panelists: interview.panelists
    }
  end

  def render("interview.json", %{interview: interview}) do
    %{
      id: interview.id,
      start_time: DateFormat.format!(interview.start_time, "%Y-%m-%dT%H:%M:%SZ", :strftime),
      interview_type_id: interview.interview_type_id,
      candidate: render_one(interview.candidate, RecruitxBackend.CandidateView, "candidate.json"),
      status_id: interview.interview_status_id
    }
  end

  def render("interview_with_panelists.json", %{interview: interview}) do
    %{
      id: interview.id,
      start_time: DateFormat.format!(interview.start_time, "%Y-%m-%dT%H:%M:%SZ", :strftime),
      interview_type_id: interview.interview_type_id,
      candidate: render_one(interview.candidate, RecruitxBackend.CandidateView, "candidate.json"),
      status_id: interview.interview_status_id,
      panelists: interview.panelists
    }
  end
end
