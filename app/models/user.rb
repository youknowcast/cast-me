# == Schema Information
#
# Table name: users
#
#  id                 :integer          not null, primary key
#  avatar             :binary
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
  AVATAR_MAX_SIZE = 64.kilobytes.freeze
  private_constant :AVATAR_MAX_SIZE

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :timeoutable

  belongs_to :family

  has_many :articles, dependent: :destroy
  has_many :plans, dependent: :destroy
  has_many :tasks, dependent: :destroy
  has_many :plan_participants, dependent: :destroy

  validates :login_id, presence: true, uniqueness: true
  validate :avatar_size_within_limit

  # 表示名を返すメソッド（login_id をそのまま使用）
  def display_name
    login_id
  end

  # アバターの data URL を返すメソッド
  def avatar_data_url
    return nil unless avatar.present?

    # 画像フォーマットを検出してBase64エンコード
    "data:image/png;base64,#{Base64.strict_encode64(avatar)}"
  end

  class << self
    def onesignal_external_id(id)
      # TODO: User の存在検証
      "user_#{id}"
    end
  end

  # OneSignal 用の external_id を生成
  # 数字のみの ID は OneSignal によってブロックされるため、プレフィックスを付ける
  # @see https://documentation.onesignal.com/docs/en/users#restricted-ids
  def onesignal_external_id
    "user_#{id}"
  end

  private

  def avatar_size_within_limit
    return unless avatar.present?
    return unless avatar.bytesize > AVATAR_MAX_SIZE

    errors.add(:avatar, 'は64KB以下にしてください')
  end
end
