# frozen_string_literal: true

class ApiToken < ApplicationRecord
  belongs_to :family

  validates :name, presence: true
  validates :token_digest, presence: true, uniqueness: true

  scope :active, -> { where(revoked_at: nil) }

  def self.digest(token) = Digest::SHA256.hexdigest(token.to_s)

  def self.issue!(family:, name:)
    raw_token = SecureRandom.urlsafe_base64(32)
    record = create!(family: family, name: name, token_digest: digest(raw_token))
    [record, raw_token]
  end

  def self.authenticate(raw_token)
    return if raw_token.blank?

    active.find_by(token_digest: digest(raw_token))
  end

  def revoked? = revoked_at.present?

  def revoke! = update!(revoked_at: Time.current)

  def touch_last_used! = update_column(:last_used_at, Time.current)
end
