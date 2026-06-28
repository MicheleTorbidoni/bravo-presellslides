module Integrations
  module Hubspot
    # Inbound webhook: a prospect booked an appointment in HubSpot. We create a
    # pre-filled PresaleSession from the flat-JSON payload. Raw JSON responses are
    # fine here — this endpoint is called server-to-server by HubSpot, not by the
    # Inertia router (see the exception in CLAUDE.md).
    class AppointmentsController < BaseController
      def create
        payload = JSON.parse(request.raw_post)
        session = ::Hubspot::CreateSessionFromBooking.call(payload)
        render json: { id: session.id }, status: :created
      rescue JSON::ParserError
        head :bad_request
      end
    end
  end
end
