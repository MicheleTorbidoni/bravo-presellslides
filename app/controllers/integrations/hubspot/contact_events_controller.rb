module Integrations
  module Hubspot
    # Inbound webhook: the prospect picked the criticalities they want to dig into,
    # via the selection email's links. HubSpot notifies us with a batch of
    # `contact.propertyChange` events; we annotate the matching session's suggested
    # criticalities. Server-to-server (not the Inertia router), so a bare head is fine.
    class ContactEventsController < BaseController
      def create
        events = JSON.parse(request.raw_post)
        ::Hubspot::ApplyContactEvents.call(events)
        head :ok
      rescue JSON::ParserError
        head :bad_request
      end
    end
  end
end
