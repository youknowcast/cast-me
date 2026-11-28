require 'digest'
require 'json'

module Api
  module V1
    class Idempotency
      CONFLICT = { error: 'idempotency_key_conflict' }.freeze

      def self.process(family:, key:, request_hash:)
        existing = ApiIdempotencyKey.active.where(family_id: family.id, key: key).order(created_at: :desc).first
        return conflict if existing && existing.request_hash != request_hash
        return replay(existing) if existing

        ActiveRecord::Base.transaction do
          status, body = yield
          store(family: family, key: key, request_hash: request_hash, status: status, body: body) if success?(status)
          [status, body]
        end
      end

      def self.request_hash(params)
        Digest::SHA256.hexdigest(JSON.generate(deep_sort(params)))
      end

      def self.deep_sort(value)
        case value
        when Hash
          value.sort_by { |k, _| k.to_s }.to_h { |k, v| [k.to_s, deep_sort(v)] }
        when Array
          value.map { |v| deep_sort(v) }
        else
          value
        end
      end

      def self.success?(status) = (200..299).cover?(status)

      def self.conflict = [409, CONFLICT]

      def self.replay(record) = [record.response_status, JSON.parse(record.response_body)]

      def self.store(family:, key:, request_hash:, status:, body:)
        ApiIdempotencyKey.create!(
          family_id: family.id,
          key: key,
          request_hash: request_hash,
          response_status: status,
          response_body: JSON.generate(body),
          created_at: Time.current
        )
      end
    end
  end
end
