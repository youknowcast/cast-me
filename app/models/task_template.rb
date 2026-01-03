class TaskTemplate < ApplicationRecord
  belongs_to :everyday_task_template
  belongs_to :user
  has_many :tasks, dependent: :nullify

  validates :title, presence: true, length: { maximum: 255 }
  validates :priority, presence: true, numericality: { only_integer: true }
end
