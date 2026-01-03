# == Schema Information
#
# Table name: task_templates
#
#  id                        :integer          not null, primary key
#  description               :text
#  priority                  :integer          default(0), not null
#  title                     :string(255)      not null
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  everyday_task_template_id :bigint           not null
#  user_id                   :bigint           not null
#
# Indexes
#
#  index_task_templates_on_everyday_task_template_id  (everyday_task_template_id)
#  index_task_templates_on_user_id                    (user_id)
#
FactoryBot.define do
  factory :task_template do
    everyday_task_template
    user
    title { '洗顔' }
    description { '洗顔料を使って洗う' }
    priority { 0 }
  end
end
