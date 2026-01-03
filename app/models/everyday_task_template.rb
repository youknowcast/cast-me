class EverydayTaskTemplate < ApplicationRecord
  belongs_to :family
  has_many :task_templates, dependent: :destroy

  validates :name, presence: true
end
