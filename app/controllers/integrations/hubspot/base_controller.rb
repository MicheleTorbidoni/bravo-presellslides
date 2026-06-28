module Integrations
  module Hubspot
    # Base controller for inbound HubSpot webhooks. It deliberately inherits from
    # ActionController::Base rather than ApplicationController so it does NOT pick
    # up the web concerns that would reject a server-to-server request:
    # `allow_browser :modern` (HubSpot has no browser UA), cookie auth
    # (`require_authentication`), or CSRF. Authentication is the signature instead.
    class BaseController < ActionController::Base
      skip_forgery_protection
      before_action :verify_signature

      private
        def verify_signature
          head :unauthorized unless signature_valid?
        end

        def signature_valid?
          ::Hubspot::WebhookSignature.valid?(
            method: request.request_method,
            url: request.original_url,
            body: request.raw_post,
            timestamp: request.headers["X-HubSpot-Request-Timestamp"],
            signature: request.headers["X-HubSpot-Signature-v3"]
          )
        end
    end
  end
end
