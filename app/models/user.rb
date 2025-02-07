# == Schema Information
#
# Table name: users
#
#  id                 :integer          not null, primary key
#  encrypted_password :string           not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  family_id          :bigint           not null
#  login_id           :string           not null
#
# Indexes
#
#  index_login_id_on_users  (login_id)
#
class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :timeoutable

  has_many :articles, dependent: :destroy

  validates :login_id, presence: true, uniqueness: true
  validates :password, presence: true, on: :create
end
