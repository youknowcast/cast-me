# == Schema Information
#
# Table name: moments
#
#  id          :integer          not null, primary key
#  description :string
#  file_path   :string
#  link        :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
class Moment < ApplicationRecord
  validates :link, presence: true
  validate :valid_url?

  def self.ransackable_attributes(_auth_object = nil)
    %w[created_at description file_path id link updated_at]
  end

  private

  def valid_url?
    url = begin
      URI.parse(link)
    rescue StandardError
      false
    end
    return false if url.is_a?(URI::HTTP) || url.is_a?(URI::HTTPS)

    errors.add(:link, 'が有効な URL ではありません')
  end
end
