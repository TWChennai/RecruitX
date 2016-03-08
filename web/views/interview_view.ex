defmodule RecruitxBackend.InterviewView do
  use RecruitxBackend.Web, :view

  alias RecruitxBackend.CandidateView
  alias RecruitxBackend.FeedbackImageView
  alias RecruitxBackend.InterviewPanelistView
  alias RecruitxBackend.InterviewView
  alias Timex.DateFormat

  def render("index.json", %{interviews_with_signup: interviews}) do
    render_many(interviews, InterviewView, "interview_with_signup.json")
  end

  def render("index.json", %{interviews_for_candidate: interviews}) do
    render_many(interviews, InterviewView, "interviews_for_candidate.json")
  end

  def render("index.json", %{interviews: interviews}) do
    %{
      total_pages: interviews.total_pages,
      interviews:  render_many(interviews.entries, InterviewView, "interview.json")
    }
  end

  def render("show.json", %{interview: interview}) do
    render_one(interview, InterviewView, "interview_with_panelists.json")
  end

  def render("success.json", %{interview: interview}) do
    %{
      id: interview.id,
      start_time: DateFormat.format!(interview.start_time, "%Y-%m-%dT%H:%M:%SZ", :strftime),
      candidate_id: interview.candidate_id,
      interview_type_id: interview.interview_type_id
    }
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
      candidate: render_one(interview.candidate, CandidateView, "candidate_with_skills.json"),
      status_id: interview.interview_status_id,
      signup: interview.signup,
      panelists: render_many(interview.interview_panelist, InterviewPanelistView, "interview_panelist.json")
    }
  end

  def render("interview.json", %{interview: interview}) do
    %{
      id: interview.id,
      start_time: DateFormat.format!(interview.start_time, "%Y-%m-%dT%H:%M:%SZ", :strftime),
      interview_type_id: interview.interview_type_id,
      candidate: render_one(interview.candidate, CandidateView, "candidate_with_skills.json"),
      status_id: interview.interview_status_id,
      last_interview_status: interview.last_interview_status,
      panelists: render_many(interview.interview_panelist, InterviewPanelistView, "interview_panelist.json")
    }
  end

  def render("interviews_for_candidate.json", %{interview: interview}) do
    %{
      id: interview.id,
      start_time: DateFormat.format!(interview.start_time, "%Y-%m-%dT%H:%M:%SZ", :strftime),
      interview_type_id: interview.interview_type_id,
      candidate: render_one(interview.candidate, CandidateView, "candidate_with_skills.json"),
      status_id: interview.interview_status_id,
      panelists: render_many(interview.interview_panelist, InterviewPanelistView, "interview_panelist.json")
    }
  end

  def render("interview_with_panelists.json", %{interview: interview}) do
    %{
      id: interview.id,
      start_time: DateFormat.format!(interview.start_time, "%Y-%m-%dT%H:%M:%SZ", :strftime),
      interview_type_id: interview.interview_type_id,
      candidate: render_one(interview.candidate, CandidateView, "candidate_with_skills.json"),
      status_id: interview.interview_status_id,
      panelists: render_many(interview.interview_panelist, InterviewPanelistView, "interview_panelist.json"),
      feedback_images: render_many(interview.feedback_images, FeedbackImageView, "feedback_image.json")
    }
  end
end
