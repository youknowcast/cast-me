# == Schema Information
#
# Table name: foods
#
#  id         :integer          not null, primary key
#  active     :boolean          default(TRUE), not null
#  name       :string(255)      not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  family_id  :bigint           not null
#
class Food < ApplicationRecord
  belongs_to :family

  validates :name, presence: true, length: { maximum: 255 },
                   uniqueness: { scope: :family_id }

  scope :for_family, ->(family_id) { where(family_id: family_id) }
  scope :active, -> { where(active: true) }
  scope :ordered_by_name, -> { order(:name) }
end
