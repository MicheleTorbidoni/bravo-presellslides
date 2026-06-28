module Hubspot
  # Turns an inbound HubSpot appointment-booking payload (the flat JSON a HubSpot
  # Workflow "Send a webhook" action posts) into a pre-filled PresaleSession, so
  # the operator finds the session ready instead of creating it by hand.
  #
  # Expected payload keys (all optional individually — a partial booking still
  # yields a session the operator can complete):
  #   contactId, firstname, lastname, company, email, jobtitle, industry,
  #   appointmentAt, salesName, location
  class CreateSessionFromBooking
    class NoOperatorError < StandardError; end

    def self.call(payload)
      new(payload).call
    end

    def initialize(payload)
      @payload = payload.to_h.with_indifferent_access
    end

    def call
      owner.presale_sessions.create!(
        contact_name: full_name,
        company_name: @payload[:company].presence,
        prospect_email: @payload[:email].presence,
        prospect_role: @payload[:jobtitle].presence,
        segment: normalized_segment,
        hubspot_contact_id: @payload[:contactId].presence&.to_s,
        appointment_at: parsed_appointment,
        appointment_sales_name: @payload[:salesName].presence,
        appointment_location: @payload[:location].presence
      )
    end

    private
      # The operator the inbound session is assigned to. Single-tenant: a
      # configurable operator, falling back to the first user.
      def owner
        user = User.find_by(email: ENV["HUBSPOT_INBOUND_OPERATOR_EMAIL"]) || User.first
        user || raise(NoOperatorError, "No user to assign the inbound HubSpot session to")
      end

      def full_name
        [ @payload[:firstname], @payload[:lastname] ].compact_blank.join(" ").presence
      end

      # Only accept an industry that maps to one of the app's known segments;
      # anything else is left blank for the operator to pick during Setup.
      def normalized_segment
        id = @payload[:industry].to_s
        id if ContentConfig.segments.any? { |s| s[:id] == id }
      end

      def parsed_appointment
        raw = @payload[:appointmentAt]
        return nil if raw.blank?

        Time.zone.parse(raw.to_s)
      rescue ArgumentError
        nil
      end
  end
end
