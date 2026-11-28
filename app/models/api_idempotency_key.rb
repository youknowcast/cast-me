class ApiIdempotencyKey < ApplicationRecord
  RETENTION = 24.hours

  belongs_to :family

  validates :key, presence: true
  validates :request_hash, presence: true
  validates :response_status, presence: true
  validates :response_body, presence: true
  validates :created_at, presence: true

  scope :active, -> { where(created_at: RETENTION.ago..) }
end
