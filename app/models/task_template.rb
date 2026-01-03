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
class TaskTemplate < ApplicationRecord
  belongs_to :everyday_task_template
  belongs_to :user
  has_many :tasks, dependent: :nullify

  validates :title, presence: true, length: { maximum: 255 }
  validates :priority, presence: true, numericality: { only_integer: true }
end
