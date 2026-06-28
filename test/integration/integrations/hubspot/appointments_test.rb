require "test_helper"

module Integrations
  module Hubspot
    class AppointmentsTest < ActionDispatch::IntegrationTest
      setup do
        # Make the assigned operator deterministic regardless of fixture ids.
        ENV["HUBSPOT_INBOUND_OPERATOR_EMAIL"] = "one@example.com"
        @url = "http://www.example.com/integrations/hubspot/appointments"
      end

      teardown do
        ENV.delete("HUBSPOT_INBOUND_OPERATOR_EMAIL")
      end

      test "a signed booking creates a pre-filled session assigned to the operator" do
        payload = {
          contactId: "12345",
          firstname: "Marco", lastname: "Rossi",
          company: "Acme Srl", email: "marco.rossi@acme.it",
          jobtitle: "Responsabile produzione",
          industry: "meccanica",
          appointmentAt: "2026-07-10T15:00:00Z",
          salesName: "Loredana Mosca", location: "Videocall"
        }

        assert_difference -> { PresaleSession.count }, 1 do
          post_signed(payload)
        end
        assert_response :created

        session = PresaleSession.order(:created_at).last
        assert_equal users(:one).id, session.user_id
        assert_equal "Marco Rossi", session.contact_name
        assert_equal "Acme Srl", session.company_name
        assert_equal "marco.rossi@acme.it", session.prospect_email
        assert_equal "Responsabile produzione", session.prospect_role
        assert_equal "meccanica", session.segment
        assert_equal "12345", session.hubspot_contact_id
        assert_equal Time.zone.parse("2026-07-10T15:00:00Z"), session.appointment_at
        assert_equal "Loredana Mosca", session.appointment_sales_name
        assert_equal "Videocall", session.appointment_location
        assert_empty session.suggested_criticalities

        assert_equal session.id, JSON.parse(response.body)["id"]
      end

      test "an unrecognized industry leaves the segment blank but still creates the session" do
        assert_difference -> { PresaleSession.count }, 1 do
          post_signed(firstname: "Ada", lastname: "Neri", industry: "settore-inventato")
        end
        assert_response :created
        assert_nil PresaleSession.order(:created_at).last.segment
      end

      test "a wrong signature is rejected and creates nothing" do
        body = { firstname: "Eve" }.to_json
        timestamp = current_timestamp

        assert_no_difference -> { PresaleSession.count } do
          post "/integrations/hubspot/appointments", params: body, headers: {
            "CONTENT_TYPE" => "application/json",
            "X-HubSpot-Request-Timestamp" => timestamp,
            "X-HubSpot-Signature-v3" => "not-the-real-signature"
          }
        end
        assert_response :unauthorized
      end

      test "a missing signature is rejected" do
        assert_no_difference -> { PresaleSession.count } do
          post "/integrations/hubspot/appointments",
            params: { firstname: "Eve" }.to_json,
            headers: { "CONTENT_TYPE" => "application/json" }
        end
        assert_response :unauthorized
      end

      private
        def current_timestamp
          (Time.now.to_f * 1000).to_i.to_s
        end

        def post_signed(payload)
          body = payload.to_json
          timestamp = current_timestamp
          signature = ::Hubspot::WebhookSignature.sign(
            method: "POST", url: @url, body: body, timestamp: timestamp
          )

          post "/integrations/hubspot/appointments", params: body, headers: {
            "CONTENT_TYPE" => "application/json",
            "X-HubSpot-Request-Timestamp" => timestamp,
            "X-HubSpot-Signature-v3" => signature
          }
        end
    end
  end
end
