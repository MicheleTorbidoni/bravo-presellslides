# Namespace for the HubSpot integration POROs (Fase 3). The integration is
# currently *simulated* — no real HubSpot is connected — but the webhook
# endpoints and signature verification are built to match HubSpot's real
# shapes, so connecting the real account later is configuration, not code.
module Hubspot
  # Shared secret used to sign/verify inbound webhooks. With real HubSpot this is
  # the client secret of the Private App; in development/test a fixed fallback
  # keeps the signed round-trip working without any external setup.
  def self.webhook_secret
    ENV.fetch("HUBSPOT_WEBHOOK_SECRET", "dev-hubspot-webhook-secret")
  end
end
