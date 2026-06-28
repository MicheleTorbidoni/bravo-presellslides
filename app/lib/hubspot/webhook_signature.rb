module Hubspot
  # Computes and verifies the HubSpot v3 request signature
  # (https://developers.hubspot.com/docs/guides/apps/authentication/validating-requests):
  # Base64(HMAC-SHA256(secret, method + uri + body + timestamp)). The same `sign`
  # is reused by the in-app simulator (M13) so a simulated request verifies
  # exactly like a real one.
  module WebhookSignature
    # Reject requests whose timestamp is older than this, to blunt replay attacks
    # (HubSpot's own recommendation).
    MAX_AGE = 5.minutes

    class << self
      def sign(method:, url:, body:, timestamp:, secret: Hubspot.webhook_secret)
        digest = OpenSSL::HMAC.digest("SHA256", secret, "#{method.to_s.upcase}#{url}#{body}#{timestamp}")
        Base64.strict_encode64(digest)
      end

      def valid?(method:, url:, body:, timestamp:, signature:, secret: Hubspot.webhook_secret)
        return false if signature.blank? || timestamp.blank?
        return false unless fresh?(timestamp)

        expected = sign(method: method, url: url, body: body, timestamp: timestamp, secret: secret)
        ActiveSupport::SecurityUtils.secure_compare(expected, signature)
      end

      private
        # HubSpot timestamps are epoch milliseconds.
        def fresh?(timestamp)
          age = Time.now.to_f * 1000 - timestamp.to_i
          age >= 0 && age <= MAX_AGE.in_milliseconds
        end
    end
  end
end
