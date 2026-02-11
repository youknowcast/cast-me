# == Schema Information
#
# Table name: article_tags
#
#  id         :integer          not null, primary key
#  article_id :bigint           not null
#  tag_id     :bigint           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_article_tags_on_article_id_and_tag_id  (article_id,tag_id) UNIQUE
#
class ArticleTag < ApplicationRecord
  belongs_to :article
  belongs_to :tag
end
