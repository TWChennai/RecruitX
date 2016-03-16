defmodule RecruitxBackend.SignUpEvaluator do

  alias RecruitxBackend.InterviewPanelist
  alias RecruitxBackend.SignUpDataContainer
  alias RecruitxBackend.Repo
  alias RecruitxBackend.SignUpEvaluationStatus
  alias RecruitxBackend.ExperienceMatrix
  alias RecruitxBackend.ExperienceEligibilityData
  alias RecruitxBackend.InterviewRelativeEvaluator

  def populate_sign_up_data_container(panelist_login_name, panelist_experience) do
    {candidate_ids_interviewed, my_previous_sign_up_start_times} = InterviewPanelist.get_candidate_ids_and_start_times_interviewed_by(panelist_login_name)
    signup_counts = InterviewPanelist.get_interview_type_based_count_of_sign_ups |> Repo.all

    %SignUpDataContainer{panelist_login_name: panelist_login_name,
    candidate_ids_interviewed: candidate_ids_interviewed,
    my_previous_sign_up_start_times: my_previous_sign_up_start_times,
    signup_counts: signup_counts,
    experience_eligibility_criteria: panelist_experience |> populate_experience_eligiblity_criteria
    }
  end

  defp populate_experience_eligiblity_criteria(panelist_experience) do
    %ExperienceEligibilityData{panelist_experience: panelist_experience,
      max_experience_with_filter: ExperienceMatrix.get_max_experience_with_filter,
      interview_types_with_filter: ExperienceMatrix.get_interview_types_with_filter,
      experience_matrix_filters: (ExperienceMatrix.filter(panelist_experience)) |> Repo.all
    }
  end

  def evaluate(sign_up_data_container, interview) do
    %SignUpEvaluationStatus{}
    |> InterviewRelativeEvaluator.evaluate(sign_up_data_container, interview)
    |> is_valid_against_experience_matrix(sign_up_data_container.experience_eligibility_criteria, interview.candidate.experience, interview.interview_type_id)
  end

  defp is_valid_against_experience_matrix(sign_up_evaluation_status, experience_eligibility_criteria, candidate_experience, interview_type_id) do
    if sign_up_evaluation_status.valid? and !ExperienceMatrix.is_eligible(candidate_experience, interview_type_id, experience_eligibility_criteria) do
      sign_up_evaluation_status = sign_up_evaluation_status |> SignUpEvaluationStatus.add_errors({:experience_matrix, "The panelist does not have enough experience"})
    end
    sign_up_evaluation_status
  end
end



