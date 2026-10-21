module WeeklyCellStreams
  extend ActiveSupport::Concern

  private

  def weekly_cell_streams(plans, participant_ids: nil)
    Array(plans).flat_map do |plan|
      weekly_cell_streams_for(plan, participant_ids || plan.participant_ids)
    end
  end

  def weekly_update_streams_for(plan, participant_ids)
    flash.now[:notice] = '予定を更新しました'
    [
      turbo_stream.replace('flash', partial: 'shared/flash'),
      *weekly_cell_streams([plan], participant_ids: participant_ids),
      turbo_stream.append('side-panel', "<div data-controller='side-panel-closer'></div>".html_safe)
    ]
  end

  def weekly_cell_streams_for(plan, participant_ids)
    member_ids = participant_ids.map(&:to_i) & current_user.family.users.ids
    member_ids.map do |member_id|
      turbo_stream.replace(
        "weekly-cell-#{member_id}-#{plan.date}",
        partial: 'weekly_dashboard/grid_cell',
        locals: { member: current_user.family.users.find(member_id),
                  day: plan.date,
                  plans: weekly_plans_for(member_id, plan.date) }
      )
    end
  end

  def weekly_plans_for(member_id, date)
    current_user.family.plans
                .for_date(date)
                .left_joins(:plan_participants)
                .where(plan_participants: { user_id: member_id, status: %i[joined pending] })
                .ordered_by_time
  end
end
