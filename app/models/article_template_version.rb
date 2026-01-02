# == Schema Information
#
# Table name: article_template_versions
#
#  id                  :integer          not null, primary key
#  version             :integer          not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  article_template_id :bigint           not null
#
# Indexes
#
#  index_article_template_versions_on_template_id_and_version  (article_template_id,version) UNIQUE
#
class ArticleTemplateVersion < ApplicationRecord
end
