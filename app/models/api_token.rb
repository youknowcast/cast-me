class ApiToken < ApplicationRecord
  belongs_to :family
  belongs_to :user, optional: true

  validates :name, presence: true
  validates :token_digest, presence: true, uniqueness: true
  validate :user_must_belong_to_family

  scope :active, -> { where(revoked_at: nil) }

  def self.digest(token) = Digest::SHA256.hexdigest(token.to_s)

  def self.issue!(family:, name:, user: nil)
    raw_token = SecureRandom.urlsafe_base64(32)
    record = create!(family: family, name: name, user: user, token_digest: digest(raw_token))
    [record, raw_token]
  end

  def self.authenticate(raw_token)
    return if raw_token.blank?

    active.find_by(token_digest: digest(raw_token))
  end

  def revoked? = revoked_at.present?

  def revoke! = update!(revoked_at: Time.current)

  def touch_last_used! = update_column(:last_used_at, Time.current)

  private

  def user_must_belong_to_family
    return if user.nil? || family.nil?
    return if user.family_id == family_id

    errors.add(:user, 'must belong to the same family')
  end
end
