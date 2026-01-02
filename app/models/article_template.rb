# == Schema Information
#
# Table name: article_templates
#
#  id         :integer          not null, primary key
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class ArticleTemplate < ApplicationRecord
end
