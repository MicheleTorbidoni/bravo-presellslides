require "application_system_test_case"

# M17 (revised) — Setup is shown twice in the flow, at the same URL, rendering
# more or less depending on whether Questionario A has already run
# (operational_profile present): "light" before it (segment + an optional
# criticality checklist only, routes into the questionnaire) and "full" after it
# (every section, criticality selection required, routes into the presentation).
# See Setup.tsx / PresaleSessionsController#setup.
class SetupStagesTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    @session = presale_sessions(:one)
    @session.update!(company_name: "Acme Spa", contact_name: "Mario Rossi")

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

  test "light pass (before Questionario A): reduced UI, criticality optional, Avanti goes to the questionnaire" do
    @session.update!(segment: nil, operational_profile: nil)
    visit setup_presale_session_path(@session)

    assert_no_text "Mostra l'introduzione"
    assert_no_text "Mostra l'hub tra le criticità"
    assert_no_text "Aggiungi criticità da un altro segmento"
    assert_no_selector "button[aria-label='Trascina per riordinare']"
    page.save_screenshot("tmp/screenshots/setup-light.png")

    # Segment alone is enough to proceed — no need to touch criticalities here.
    react_click "Meccanica"
    react_click "Avanti"
    assert_current_path profiling_presale_session_path(@session), wait: 5
    assert_equal "meccanica", @session.reload.segment
  end

  test "light pass without a segment shows the same validation as the full pass" do
    @session.update!(segment: nil, operational_profile: nil)
    visit setup_presale_session_path(@session)

    react_click "Avanti"
    assert_text "Seleziona un segmento per continuare."
    assert_current_path setup_presale_session_path(@session)
  end

  test "full pass (after Questionario A): every section shown, criticality required, Avanti goes to the presentation" do
    @session.update!(segment: "meccanica", operational_profile: "ho-excel-bom-bom1")
    visit setup_presale_session_path(@session)

    assert_text "Mostra l'introduzione"
    assert_text "Mostra l'hub tra le criticità"
    assert_text "Aggiungi criticità da un altro segmento"
    assert_selector "button[aria-label='Trascina per riordinare']", minimum: 1
    page.save_screenshot("tmp/screenshots/setup-full.png")

    react_click "Avanti"
    assert_current_path present_presale_session_path(@session), wait: 5
  end
end
