require "test_helper"

module Hubspot
  # The networked #call (real signed POST to the running server) is exercised in the
  # browser; here we unit-test the placeholder/payload builders and prove that the
  # bodies and signatures the simulator produces pass the *real* endpoints' verification.
  class SimulateBookingTest < ActionDispatch::IntegrationTest
    setup do
      ENV["HUBSPOT_INBOUND_OPERATOR_EMAIL"] = "one@example.com"
      @sim = ::Hubspot::SimulateBooking.new(base_url: "http://www.example.com")
    end

    teardown { ENV.delete("HUBSPOT_INBOUND_OPERATOR_EMAIL") }

    test "generate_data yields a known segment and the full booking shape" do
      data = @sim.generate_data

      assert_includes ContentConfig.segments.map { |s| s[:id] }, data[:industry]
      %i[ contactId firstname lastname company email jobtitle industry appointmentAt salesName location ].each do |key|
        assert data[key].present?, "expected #{key} to be present"
      end
      assert_nothing_raised { Time.zone.parse(data[:appointmentAt]) }
    end

    test "random_suggested is a non-empty, deduped, sorted subset of the segment subset" do
      subset = ContentConfig.criticalities_for_segment(segment: "meccanica").map { |c| c[:id] }
      picked = @sim.random_suggested(segment: "meccanica")

      assert picked.any?
      assert_empty(picked - subset)
      assert_equal picked.uniq.sort, picked
    end

    test "random_suggested picks at most two criticalities across many runs" do
      subset_size = ContentConfig.criticalities_for_segment(segment: "meccanica").size
      cap = [ 2, subset_size ].min

      50.times do
        picked = @sim.random_suggested(segment: "meccanica")
        assert picked.size.between?(1, cap),
          "expected 1..#{cap} suggested, got #{picked.size}"
      end
    end

    test "random_suggested is empty for an unknown segment" do
      assert_empty @sim.random_suggested(segment: "settore-inventato")
    end

    test "the appointment body the simulator builds passes verification and creates a session" do
      data = @sim.generate_data

      assert_difference -> { PresaleSession.count }, 1 do
        post_signed("/integrations/hubspot/appointments", @sim.appointment_body(data))
      end
      assert_response :created

      session = PresaleSession.order(:created_at).last
      assert_equal "#{data[:firstname]} #{data[:lastname]}", session.contact_name
      assert_equal data[:contactId].to_s, session.hubspot_contact_id
      assert_equal data[:industry], session.segment
    end

    test "the selection body the simulator builds annotates the suggested criticalities" do
      data = @sim.generate_data
      post_signed("/integrations/hubspot/appointments", @sim.appointment_body(data))
      session = PresaleSession.order(:created_at).last

      ids = @sim.random_suggested(segment: data[:industry])
      post_signed(
        "/integrations/hubspot/contact_events",
        @sim.selection_body(contact_id: data[:contactId], criticality_ids: ids)
      )
      assert_response :ok
      assert_equal ids.sort, session.reload.suggested_criticalities
    end

    private
      # Signs and posts exactly as SimulateBooking#post_signed would, but through the
      # integration test client (no socket needed).
      def post_signed(path, body)
        url = "http://www.example.com#{path}"
        timestamp = (Time.now.to_f * 1000).to_i.to_s
        signature = ::Hubspot::WebhookSignature.sign(method: "POST", url: url, body: body, timestamp: timestamp)

        post path, params: body, headers: {
          "CONTENT_TYPE" => "application/json",
          "X-HubSpot-Request-Timestamp" => timestamp,
          "X-HubSpot-Signature-v3" => signature
        }
      end
  end
end
