defmodule PanelSpec do
  use ESpec.Phoenix, model: RecruitxBackend.Panel

  alias RecruitxBackend.Interview
  alias RecruitxBackend.InterviewPanelist
  alias RecruitxBackend.Panel
  alias RecruitxBackend.Repo
  alias RecruitxBackend.SlotPanelist
  alias RecruitxBackend.TimexHelper

  describe "methods" do
    context "format panelist names" do
      it "should return empty string when there are no panelists" do
        expect Panel.format_names([]) |> to(eq(""))
      end
      it "should return comma separated panelist names" do
        panelist1 = create(:interview_panelist)
        panelist2 = create(:interview_panelist)
        expect Panel.format_names([panelist1, panelist2]) |> to(eq(panelist1.panelist_login_name <> ", " <> panelist2.panelist_login_name))
      end
      it "should return panelist name without comma for single panelist" do
        panelist1 = create(:interview_panelist)
        expect Panel.format_names([panelist1]) |> to(eq(panelist1.panelist_login_name))
      end
    end
    context "default_order" do
      before do: Repo.delete_all(Interview)

      it "should sort by ascending order of start time" do
        now = TimexHelper.utc_now()
        interview_with_start_date1 = create(:interview, start_time: now |> TimexHelper.add(1, :days))
        interview_with_start_date2 = create(:interview, start_time: now |> TimexHelper.add(3, :days))
        interview_with_start_date3 = create(:interview, start_time: now |> TimexHelper.add(-2, :days))
        interview_with_start_date4 = create(:interview, start_time: now |> TimexHelper.add(-5, :days))

        [interview1, interview2, interview3, interview4] = Interview |> Panel.default_order |> Repo.all

        expect(interview1.start_time) |> to(eq(interview_with_start_date4.start_time))
        expect(interview2.start_time) |> to(eq(interview_with_start_date3.start_time))
        expect(interview3.start_time) |> to(eq(interview_with_start_date1.start_time))
        expect(interview4.start_time) |> to(eq(interview_with_start_date2.start_time))
      end

      it "should tie-break on id for the same start time" do
        now = TimexHelper.utc_now()
        interview_with_start_date1 = create(:interview, start_time: now |> TimexHelper.add(1, :days), id: 1)
        interview_with_same_start_date1 = create(:interview, start_time: now |> TimexHelper.add(1, :days), id: interview_with_start_date1.id + 1)
        interview_with_start_date2 = create(:interview, start_time: now |> TimexHelper.add(2, :days))

        [interview1, interview2, interview3] = Interview |> Panel.default_order |> Repo.all

        expect(interview1.start_time) |> to(eq(interview_with_start_date1.start_time))
        expect(interview2.start_time) |> to(eq(interview_with_same_start_date1.start_time))
        expect(interview3.start_time) |> to(eq(interview_with_start_date2.start_time))
      end
    end

    context "get the interviews in the next 7 days" do
      it "should return the interview from the next 7 days" do
        Repo.delete_all(Interview)
        create(:interview, id: 900, start_time: TimexHelper.utc_now() |> TimexHelper.add(+8, :days))
        create(:interview, id: 901, start_time: TimexHelper.utc_now() |> TimexHelper.add(-6, :days))
        create(:interview, id: 902, start_time: TimexHelper.utc_now() |> TimexHelper.add(+1, :days))

        actual_result = Interview |> Panel.now_or_in_next_seven_days |> Repo.one

        expect(actual_result.id) |> to(be(902))
      end
    end

    context "get_start_times_interviewed_by" do
      it "should give only interview's start_time of a panelist if there are no slots for that panelist" do
        Repo.delete_all(InterviewPanelist)
        interview_panelist = create(:interview_panelist, panelist_login_name: "recruitx")
        interview_start_time = Repo.preload(interview_panelist, :interview).interview.start_time
        response = Panel.get_start_times_interviewed_by("recruitx")

        expect(response) |> to(be([interview_start_time]))
      end

      it "should give only slot's start_time of a panelist if there are no interviews for that panelist" do
        Repo.delete_all(SlotPanelist)
        slot_panelist = create(:slot_panelist, panelist_login_name: "recruitx")
        slot_start_time = Repo.preload(slot_panelist, :slot).slot.start_time
        response = Panel.get_start_times_interviewed_by("recruitx")

        expect(response) |> to(be([slot_start_time]))
      end

      it "should give both interview's and slot's start_time of a panelist" do
        Repo.delete_all(InterviewPanelist)
        Repo.delete_all(SlotPanelist)
        interview_panelist = create(:interview_panelist, panelist_login_name: "recruitx")
        slot_panelist = create(:slot_panelist, panelist_login_name: "recruitx")
        interview_start_time = Repo.preload(interview_panelist, :interview).interview.start_time
        slot_start_time = Repo.preload(slot_panelist, :slot).slot.start_time
        response = Panel.get_start_times_interviewed_by("recruitx")

        expect(response) |> to(be([interview_start_time, slot_start_time]))
      end
    end

    context "desc_order" do
      before do: Repo.delete_all(Interview)
      it "should sort by descending order of start time" do
        now = TimexHelper.utc_now()
        interview_with_start_date1 = create(:interview, start_time: now |> TimexHelper.add(1, :days))
        interview_with_start_date2 = create(:interview, start_time: now |> TimexHelper.add(3, :days))
        interview_with_start_date3 = create(:interview, start_time: now |> TimexHelper.add(-2, :days))
        interview_with_start_date4 = create(:interview, start_time: now |> TimexHelper.add(-5, :days))

        [interview1, interview2, interview3, interview4] = Interview |> Panel.descending_order |> Repo.all

        expect(interview1.start_time) |> to(eq(interview_with_start_date2.start_time))
        expect(interview2.start_time) |> to(eq(interview_with_start_date1.start_time))
        expect(interview3.start_time) |> to(eq(interview_with_start_date3.start_time))
        expect(interview4.start_time) |> to(eq(interview_with_start_date4.start_time))
      end

      it "should tie-break on id for the same start time" do
        now = TimexHelper.utc_now()
        interview_with_start_date1 = create(:interview, start_time: now |> TimexHelper.add(1, :days), id: 1)
        interview_with_same_start_date1 = create(:interview, start_time: now |> TimexHelper.add(1, :days), id: interview_with_start_date1.id + 1)
        interview_with_start_date2 = create(:interview, start_time: now |> TimexHelper.add(2, :days))

        [interview1, interview2, interview3] = Interview |> Panel.descending_order |> Repo.all

        expect(interview1.start_time) |> to(eq(interview_with_start_date2.start_time))
        expect(interview2.start_time) |> to(eq(interview_with_same_start_date1.start_time))
        expect(interview3.start_time) |> to(eq(interview_with_start_date1.start_time))
      end
    end
  end
end
