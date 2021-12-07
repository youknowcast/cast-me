# == Schema Information
#
# Table name: moments
#
#  id          :bigint           not null, primary key
#  description :string(255)
#  file_path   :string(255)
#  link        :string(255)
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
class Moment < ApplicationRecord
end
