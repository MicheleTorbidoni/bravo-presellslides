require "test_helper"

module Integrations
  module Hubspot
    class ContactEventsTest < ActionDispatch::IntegrationTest
      setup do
        @url = "http://www.example.com/integrations/hubspot/contact_events"
        @session = users(:one).presale_sessions.create!(
          company_name: "Acme Srl", segment: "meccanica", hubspot_contact_id: "12345"
        )
      end

      test "a signed selection event annotates the matching session's suggested criticalities" do
        post_signed([ property_change(object_id: "12345", value: "8;3;7") ])

        assert_response :ok
        # Filtered to valid ids, deduped and sorted.
        assert_equal [ 3, 7, 8 ], @session.reload.suggested_criticalities
      end

      test "the write is idempotent: a later event replaces the stored set" do
        post_signed([ property_change(object_id: "12345", value: "3;7") ])
        assert_equal [ 3, 7 ], @session.reload.suggested_criticalities

        post_signed([ property_change(object_id: "12345", value: "1;2") ])
        assert_equal [ 1, 2 ], @session.reload.suggested_criticalities
      end

      test "unknown ids in the value are dropped" do
        post_signed([ property_change(object_id: "12345", value: "3;999;abc;7") ])

        assert_equal [ 3, 7 ], @session.reload.suggested_criticalities
      end

      test "an event for an unknown contact is a no-op" do
        assert_no_changes -> { @session.reload.suggested_criticalities } do
          post_signed([ property_change(object_id: "99999", value: "1;2") ])
        end
        assert_response :ok
      end

      test "events on other properties are ignored" do
        assert_no_changes -> { @session.reload.suggested_criticalities } do
          post_signed([ property_change(object_id: "12345", property: "lifecyclestage", value: "customer") ])
        end
        assert_response :ok
      end

      test "a wrong signature is rejected and changes nothing" do
        body = [ property_change(object_id: "12345", value: "1;2") ].to_json
        assert_no_changes -> { @session.reload.suggested_criticalities } do
          post "/integrations/hubspot/contact_events", params: body, headers: {
            "CONTENT_TYPE" => "application/json",
            "X-HubSpot-Request-Timestamp" => current_timestamp,
            "X-HubSpot-Signature-v3" => "nope"
          }
        end
        assert_response :unauthorized
      end

      private
        def property_change(object_id:, value:, property: ::Hubspot::CRITICALITY_PROPERTY)
          {
            objectId: object_id,
            subscriptionType: "contact.propertyChange",
            propertyName: property,
            propertyValue: value
          }
        end

        def current_timestamp
          (Time.now.to_f * 1000).to_i.to_s
        end

        def post_signed(events)
          body = events.to_json
          timestamp = current_timestamp
          signature = ::Hubspot::WebhookSignature.sign(
            method: "POST", url: @url, body: body, timestamp: timestamp
          )

          post "/integrations/hubspot/contact_events", params: body, headers: {
            "CONTENT_TYPE" => "application/json",
            "X-HubSpot-Request-Timestamp" => timestamp,
            "X-HubSpot-Signature-v3" => signature
          }
        end
    end
  end
end
