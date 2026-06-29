require "test_helper"
require "minitest/mock"

class Admin::HubspotSimulatorControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    @user = users(:one)
    @password = "password"
  end

  test "unauthenticated users are redirected to login" do
    get admin_hubspot_simulator_path
    assert_redirected_to login_path
  end

  test "non-admin users are redirected to root" do
    log_in_as(@user)
    get admin_hubspot_simulator_path
    assert_redirected_to root_path
  end

  test "admin users can view the simulator" do
    log_in_as(@admin)
    get admin_hubspot_simulator_path
    assert_response :success
  end

  test "simulate runs the round-trip and carries the created session to the page" do
    log_in_as(@admin)
    session = @user.presale_sessions.create!(
      company_name: "Acme Srl", contact_name: "Marco Rossi",
      segment: "meccanica", suggested_criticalities: [ 1, 2 ]
    )
    result = ::Hubspot::SimulateBooking::Result.new(session_id: session.id, data: {}, suggested_ids: [ 1, 2 ])

    ::Hubspot::SimulateBooking.stub(:call, ->(**) { result }) do
      post admin_simulate_hubspot_simulator_path
    end

    assert_redirected_to admin_hubspot_simulator_path
    assert_match(/Prenotazione simulata/, flash[:notice])
    assert_equal session.id, flash[:created_session_id]

    follow_redirect!
    props = JSON.parse(CGI.unescapeHTML(response.body[/data-page="([^"]*)"/, 1]))["props"]
    assert_equal session.id, props.dig("createdSession", "id")
    assert_equal "Meccanica", props.dig("createdSession", "segment_label")
  end

  test "simulate surfaces an error when there is no operator to assign" do
    log_in_as(@admin)

    ::Hubspot::SimulateBooking.stub(:call, ->(**) { raise ::Hubspot::CreateSessionFromBooking::NoOperatorError }) do
      post admin_simulate_hubspot_simulator_path
    end

    assert_redirected_to admin_hubspot_simulator_path
    assert flash[:created_session_id].blank?
  end

  private
    def log_in_as(user)
      post login_path, params: { email: user.email, password: @password }
    end
end
