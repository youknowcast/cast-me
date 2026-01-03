# == Schema Information
#
# Table name: families
#
#  id         :integer          not null, primary key
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class Family < ApplicationRecord
  has_many :users, dependent: :destroy
  has_many :plans, dependent: :destroy
  has_many :tasks, dependent: :destroy
  has_many :regular_tasks, dependent: :destroy
  has_many :everyday_task_templates, dependent: :destroy

  validates :name, presence: true, length: { maximum: 100 }
end
