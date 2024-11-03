# == Schema Information
#
# Table name: article_templates
#
#  id         :bigint           not null, primary key
#  name       :string(255)      not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class ArticleTemplate < ApplicationRecord

end
