# == Schema Information
#
# Table name: users
#
#  id              :bigint           not null, primary key
#  password_digest :string(255)      not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  login_id        :string(255)      not null
#
# Indexes
#
#  index_login_id_on_users  (login_id)
#
class User < ApplicationRecord

end
