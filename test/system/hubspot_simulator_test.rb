require "application_system_test_case"

# Exercises the M13 simulator end-to-end against a real running server: the click
# triggers SimulateBooking#call, which makes *real* signed Net::HTTP POSTs to the two
# webhook endpoints (the part unit tests can't cover without a socket). Then it opens
# the created session's hub and checks the suggested-criticality star renders, coexisting
# with the completed shield. Saves desktop + mobile screenshots.
class HubspotSimulatorTest < ApplicationSystemTestCase
  setup do
    @admin = users(:admin)

    visit login_path
    react_fill "email", @admin.email
    react_fill "password", "password"
    react_click "Log in"
    assert_current_path dashboard_path, wait: 5
  end

  test "simulating a booking creates a session and the hub shows the suggested star" do
    visit admin_hubspot_simulator_path
    assert_text "HubSpot Simulator"
    page.save_screenshot("tmp/screenshots/hubspot-simulator.png")

    assert_difference -> { PresaleSession.count }, 1 do
      react_click "Simula prenotazione da HubSpot"
      # The real signed round-trip runs server-side before the redirect lands.
      assert_text "Sessione creata", wait: 10
    end
    page.save_screenshot("tmp/screenshots/hubspot-simulator-created.png")

    session = PresaleSession.order(:created_at).last
    assert session.suggested_criticalities.any?, "expected the simulator to apply suggested criticalities"

    # Mark one suggested criticality as also discussed, to prove star + shield coexist.
    suggested_id = session.suggested_criticalities.first
    session.update!(discussed_criticalities: [ suggested_id ])

    visit present_presale_session_path(session)
    skip_intro

    # The suggested pills carry the amber star; the discussed one also carries the shield.
    assert_selector "svg.lucide-star", wait: 5
    assert_selector "svg.lucide-shield-check", wait: 5
    page.save_screenshot("tmp/screenshots/hub-suggested-badge-desktop.png")

    # Mobile width: the stage scales but the badges remain in the DOM.
    current_window.resize_to(390, 844)
    visit present_presale_session_path(session)
    skip_intro
    assert_selector "svg.lucide-star", wait: 5
    page.save_screenshot("tmp/screenshots/hub-suggested-badge-mobile.png")
  end

  # ---- helpers (mirror present_flow_test.rb: native Selenium clicks/fills on the
  # React surfaces are flaky in headless Chrome, so dispatch via JS) ----

  def react_click(text)
    page.execute_script("arguments[0].click()", find("button", text: text))
  end

  def react_fill(field, value)
    input = find("input[name='#{field}'], ##{field}", match: :first)
    page.execute_script(<<~JS, input, value)
      const el = arguments[0]
      const setter = Object.getOwnPropertyDescriptor(
        window.HTMLInputElement.prototype, "value"
      ).set
      setter.call(el, arguments[1])
      el.dispatchEvent(new Event("input", { bubbles: true }))
    JS
  end

  def press_key(key)
    page.execute_script(
      "window.dispatchEvent(new KeyboardEvent('keydown', { key: '#{key}', bubbles: true }))"
    )
  end

  def skip_intro
    10.times do
      break if page.has_text?("Dove fa più difficoltà la tua azienda?", wait: 0.2)
      press_key("ArrowRight")
    end
    assert_text "Dove fa più difficoltà la tua azienda?"
  end
end
