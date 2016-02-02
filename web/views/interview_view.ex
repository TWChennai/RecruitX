defmodule RecruitxBackend.InterviewView do
  use RecruitxBackend.Web, :view

 def render("index.json", %{interviews: interviews}) do
    render_many(interviews, RecruitxBackend.InterviewView, "interview.json")
  end

 def render("interview.json", %{interview: interview}) do
    %{
      id: interview.id,
      start_time: interview.start_time,
      candidate: render_one(interview.candidate, RecruitxBackend.CandidateView, "candidate.json"),
      interview_type: render_one(interview.interview_type, RecruitxBackend.InterviewTypeView, "interview_type_without_id.json")
    }
  end
end
