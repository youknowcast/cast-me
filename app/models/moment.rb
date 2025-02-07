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

  private

  def self.ransackable_attributes(auth_object = nil)
    %w[created_at description file_path id link updated_at]
  end

  def valid_url?
    url = URI.parse(link) rescue false
    unless url.kind_of?(URI::HTTP) || url.kind_of?(URI::HTTPS)
      errors.add(:link, 'が有効な URL ではありません')
    end
  end
end
