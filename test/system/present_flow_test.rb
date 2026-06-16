require "application_system_test_case"

class PresentFlowTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    @session = presale_sessions(:one)
    # A profiled session whose (segment x profile) resolves to a known subset
    # (criticalities 1, 3, 4, 7, 12 per content/config/mappings.json).
    @session.update!(
      company_name: "Acme Spa",
      contact_name: "Mario Rossi",
      segment: "meccanica",
      operational_profile: "ho-excel-bom-bom1"
    )

    visit login_path
    fill_in "email", with: @user.email
    fill_in "password", with: "password"
    # Use the JS-dispatched click (see react_click) — native Selenium clicks on
    # this React submit button are flaky in headless Chrome and intermittently
    # fail to submit, leaving us stranded on /login.
    react_click "Log in"
    # Wait for the async Inertia login POST + redirect to land on the dashboard
    # before navigating on (a generous wait — the round trip occasionally takes
    # over Capybara's 2s default), otherwise the next visit races ahead
    # unauthenticated.
    assert_current_path dashboard_path, wait: 5
  end

  # Native Selenium clicks on these React-handled buttons are unreliable in
  # headless Chrome (the trusted click intermittently fails to fire the onClick).
  # Dispatching the click via JS is reliable and the state assertions below still
  # validate the full feature behaviour; real browsers fire the handlers fine.
  def react_click(text)
    page.execute_script("arguments[0].click()", find("button", text: text))
  end

  # The capture overlay uses an uncontrolled-feeling React textarea; set the value
  # and dispatch an input event so React's onChange picks it up reliably in headless.
  def fill_in_question(text)
    textarea = find("textarea")
    page.execute_script(<<~JS, textarea, text)
      const el = arguments[0]
      const setter = Object.getOwnPropertyDescriptor(
        window.HTMLTextAreaElement.prototype, "value"
      ).set
      setter.call(el, arguments[1])
      el.dispatchEvent(new Event("input", { bubbles: true }))
    JS
  end

  test "operator runs the hub loop and reaches the closing page" do
    visit present_presale_session_path(@session)

    assert_text "Dove fa più difficoltà la tua azienda?"
    # The resolved subset is pre-filtered into the hub.
    assert_text "Tempi di produzione non raccolti"
    page.save_screenshot("tmp/screenshots/present-hub.png")

    # Nothing selected yet → the start button is disabled.
    assert_button "Avvia presentazione", disabled: true

    # Select two criticalities, then start the presentation.
    react_click "Tempi di produzione non raccolti"
    react_click "Date di consegna inaffidabili"
    assert_button "Avvia presentazione", disabled: false
    react_click "Avvia presentazione"

    # The real slide player renders the first criticality's first slide (concept),
    # with the prospect's name interpolated into the screenshot slide further on.
    assert_text "Un ciclo assistito e fluido."
    page.save_screenshot("tmp/screenshots/present-slide-concept.png")

    # Capture a question with `Q`, type it, and save it — it persists on the session
    # bound to the current slide.
    page.execute_script(
      "window.dispatchEvent(new KeyboardEvent('keydown', { key: 'q', bubbles: true }))"
    )
    assert_text "Cattura domanda"
    fill_in_question("È compatibile col nostro gestionale?")
    react_click "Salva domanda"
    assert_no_text "Cattura domanda"

    # Step through every slide/step with the right arrow until the flow completes
    # and we return to the hub (concept → screenshot → sequence ×3 steps).
    8.times do
      page.execute_script(
        "window.dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowRight', bubbles: true }))"
      )
    end
    assert_text "Dove fa più difficoltà la tua azienda?"
    # One criticality discussed, another still pending → "Continua" is enabled.
    assert_button "Continua", disabled: false

    # The completion is persisted on the session.
    assert_equal [ 1 ], @session.reload.discussed_criticalities

    # The captured question persisted, bound to criticality 1 and a slide.
    questions = @session.reload.captured_questions
    assert_equal 1, questions.length
    assert_equal "È compatibile col nostro gestionale?", questions.first["text"]
    assert_equal 1, questions.first["criticality_id"]
    assert questions.first["slide_id"].present?

    # The `C` shortcut jumps to the closing page from anywhere, with the
    # prospect's names interpolated. Dispatch the keydown on window directly so it
    # reaches the global listener regardless of the focused element in headless Chrome.
    page.execute_script(
      "window.dispatchEvent(new KeyboardEvent('keydown', { key: 'c', bubbles: true }))"
    )
    assert_text "Grazie, Mario Rossi."
    assert_text "Acme Spa"
    page.save_screenshot("tmp/screenshots/present-closing.png")

    # Reaching the closing page marks the session closed.
    assert_equal "closed", @session.reload.status
  end

  test "the S shortcut leaves the presentation for the sessions list" do
    visit present_presale_session_path(@session)
    assert_text "Dove fa più difficoltà la tua azienda?"

    page.execute_script(
      "window.dispatchEvent(new KeyboardEvent('keydown', { key: 's', bubbles: true }))"
    )

    assert_current_path presale_sessions_path
  end
end
