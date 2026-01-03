# == Schema Information
#
# Table name: tasks
#
#  id               :integer          not null, primary key
#  completed        :boolean          default(FALSE), not null
#  date             :date             not null
#  description      :text
#  priority         :integer          default(0), not null
#  title            :string(255)      not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  family_id        :bigint           not null
#  task_template_id :bigint
#  user_id          :bigint           not null
#
# Indexes
#
#  index_tasks_on_date_and_completed  (date,completed)
#  index_tasks_on_family_id_and_date  (family_id,date)
#  index_tasks_on_task_template_id    (task_template_id)
#  index_tasks_on_user_id_and_date    (user_id,date)
#
FactoryBot.define do
  factory :task do
    association :family
    association :user
    title { 'Test Task' }
    date { Time.zone.today }
    priority { 1 }
    completed { false }
  end
end
