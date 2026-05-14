# == Schema Information
#
# Table name: articles
#
#  id          :integer          not null, primary key
#  pinned      :boolean          default(FALSE), not null
#  title       :string           not null
#  description :text
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  user_id     :bigint           not null
#
# Indexes
#
#  index_articles_on_user_id  (user_id)
#
class Article < ApplicationRecord
  belongs_to :user
  has_many :article_tags, dependent: :destroy
  has_many :tags, through: :article_tags

  validates :title, presence: true

  scope :by_priority, -> { order(pinned: :desc, updated_at: :desc) }

  # Virtual attribute for handling tags input as string
  def tag_list
    tags.map(&:name).join(', ')
  end

  def tag_list=(names)
    self.tags = names.split(',').map do |n|
      Tag.where(name: n.strip).first_or_create!
    end
  end
end
