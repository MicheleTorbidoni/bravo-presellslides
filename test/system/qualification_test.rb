require "application_system_test_case"

# M17 — Fase 6: Questionario B, reached from the presentation's closing screen
# ("Completa scheda"). Shows only the phase-2 qualification group (today: the
# reduced "Azienda" — headcount/turnover). No decision-tree questions here, so no
# gate: the final button is always enabled and leads straight to the results page.
class QualificationTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    @session = presale_sessions(:one)
    @session.update!(
      company_name: "Acme Spa", contact_name: "Mario Rossi",
      segment: "meccanica", operational_profile: "ho-excel-bom-bom1",
      qualification_answers: {}
    )

    visit login_path
    react_fill "email", @user.email
    react_fill "password", "password"
    react_click "Log in"
    assert_current_path presale_sessions_path, wait: 5
  end

  def react_click(text)
    page.execute_script("arguments[0].click()", find("button", text: text))
  end

  def react_fill(field, value)
    set_value(find("input[name='#{field}'], ##{field}", match: :first), value)
  end

  def set_value(el, value)
    page.execute_script(<<~JS, el, value)
      const el = arguments[0]
      const setter = Object.getOwnPropertyDescriptor(
        window.HTMLInputElement.prototype, "value"
      ).set
      setter.call(el, arguments[1])
      el.dispatchEvent(new Event("input", { bubbles: true }))
    JS
  end

  test "shows only the Azienda group, no gate, and no way back" do
    visit qualification_presale_session_path(@session)

    assert_selector "h2", text: "Azienda"
    assert_no_selector "h2", text: "Interlocutore"
    assert_no_selector "legend", text: "Human Only" # no decision-tree questions here
    assert_no_button "Indietro"
    assert_no_button "Chiudi"

    # No gate: the final button is enabled from the start.
    assert_button "Vai al riepilogo", disabled: false
    page.save_screenshot("tmp/screenshots/qualification-desktop.png")
  end

  test "totale persone auto-sums the counts, with a manual override that wins until cleared" do
    visit qualification_presale_session_path(@session)

    react_fill "qf-production_operators_count", "2"
    react_fill "qf-technical_office_people_count", "3"
    react_fill "qf-administrative_people_count", "1"
    react_fill "qf-other_office_people_count", "4"

    # Auto-sum = 2 + 3 + 1 + 4.
    assert_equal "10", find("#qf-total_people_count").value

    # Manual override: total holds its typed value even when a count changes.
    react_fill "qf-total_people_count", "99"
    react_fill "qf-production_operators_count", "5"
    assert_equal "99", find("#qf-total_people_count").value

    # Clearing the total resumes the auto-sum: now 5 + 3 + 1 + 4.
    react_fill "qf-total_people_count", ""
    assert_equal "13", find("#qf-total_people_count").value
  end

  test "numeric fields show inline, non-blocking validation" do
    visit qualification_presale_session_path(@session)

    react_fill "qf-production_operators_count", "-1"
    assert_text "Inserisci un valore maggiore o uguale a 0."
    assert_button "Vai al riepilogo", disabled: false
  end

  test "auto-saves and restores on reload" do
    visit qualification_presale_session_path(@session)

    react_fill "qf-annual_turnover_amount", "1500000"
    sleep 0.6
    assert_equal 1_500_000, @session.reload.qualification_answers["annual_turnover_amount"]

    visit qualification_presale_session_path(@session)
    assert_equal "1500000", find("#qf-annual_turnover_amount").value
  end

  test "the final button marks the session closed and leads to the debrief" do
    visit qualification_presale_session_path(@session)

    react_click "Vai al riepilogo"
    assert_current_path debrief_presale_session_path(@session), wait: 5
    assert_equal "closed", @session.reload.status
  end

  test "renders correctly at mobile width" do
    page.driver.browser.manage.window.resize_to(390, 900)
    visit qualification_presale_session_path(@session)
    assert_selector "h2", text: "Azienda"
    page.save_screenshot("tmp/screenshots/qualification-mobile.png")
  end
end
