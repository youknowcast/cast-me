# == Schema Information
#
# Table name: articles
#
#  id                          :bigint           not null, primary key
#  date                        :date             not null
#  description                 :text(65535)
#  display_order               :integer          default(0), not null
#  sequence_number             :integer          not null
#  title                       :string(255)      not null
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  article_template_version_id :bigint           not null
#  user_id                     :bigint           not null
#
# Indexes
#
#  index_articles_on_user_id_and_date_and_sequence_number  (user_id,date,sequence_number) UNIQUE
#
class Article < ApplicationRecord

end
