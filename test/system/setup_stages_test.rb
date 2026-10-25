require "application_system_test_case"

# Fase 8 — Setup is shown once, as the first step of the flow, and holds the
# whole presentation configuration: prospect data, segment, the criticality
# selection (always the full catalogue, independent of the segment) and its
# order, and the intro/hub toggles. "Avanti" leads into Questionario A, which
# then goes straight into the presentation. See Setup.tsx /
# PresaleSessionsController#setup.
class SetupStagesTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    @session = presale_sessions(:one)
    @session.update!(company_name: "Acme Spa", contact_name: "Mario Rossi",
      segment: nil, operational_profile: nil)

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

  def toggle(label)
    input = find("li", text: label).find("input[type='checkbox']")
    page.execute_script("arguments[0].click()", input)
  end

  test "every section is shown up front, with the toggles pre-checked and no criticality enabled" do
    visit setup_presale_session_path(@session)

    # The whole catalogue is visible even before a segment is chosen.
    assert_selector "button[aria-label='Trascina per riordinare']", count: ContentConfig.criticalities.size
    assert_no_selector "li input[type='checkbox']:checked"
    assert_no_text "Tipica del segmento"
    assert_no_text "Aggiungi criticità da un altro segmento"
    assert find("label", text: "Mostra l'introduzione all'inizio").find("input").checked?
    assert find("label", text: "Mostra l'hub tra le criticità").find("input").checked?
    page.save_screenshot("tmp/screenshots/setup-single.png")
  end

  test "at phone width the setup has no horizontal scroll" do
    @session.update!(segment: "meccanica", suggested_criticalities: [ 9 ])
    page.driver.browser.manage.window.resize_to(390, 900)
    visit setup_presale_session_path(@session)

    assert_text "Criticità da discutere"
    row = find("li", text: "Indicata dal prospect")
    page.execute_script("arguments[0].scrollIntoView({ block: \"center\" })", row)
    sleep 0.3
    page.save_screenshot("tmp/screenshots/setup-single-mobile.png")
    assert_equal page.evaluate_script("window.innerWidth"),
      page.evaluate_script("document.documentElement.scrollWidth")
  ensure
    page.driver.browser.manage.window.resize_to(1400, 1400)
  end

  test "switching segment only moves the 'Tipica del segmento' hint and keeps the selection" do
    visit setup_presale_session_path(@session)

    react_click "Meccanica"
    meccanica = ContentConfig.criticalities_for_segment(segment: "meccanica").size
    assert_selector "li", text: "Tipica del segmento", count: meccanica

    toggle "Tempi di produzione non raccolti"
    react_click "Elettronica"
    elettronica = ContentConfig.criticalities_for_segment(segment: "elettronica").size
    assert_selector "li", text: "Tipica del segmento", count: elettronica
    # The selection survives the segment switch.
    assert find("li", text: "Tempi di produzione non raccolti").find("input[type='checkbox']").checked?
  end

  test "Avanti requires a segment and at least one criticality, then goes to the questionnaire" do
    visit setup_presale_session_path(@session)

    react_click "Avanti"
    assert_text "Seleziona un segmento per continuare."
    assert_text "Abilita almeno una criticità per continuare."
    assert_current_path setup_presale_session_path(@session)

    react_click "Meccanica"
    toggle "Tempi di produzione non raccolti"
    react_click "Avanti"
    assert_current_path profiling_presale_session_path(@session), wait: 5
    assert_equal "meccanica", @session.reload.segment
    assert_equal [ 1 ], @session.selected_criticalities
  end

  test "HubSpot suggestions arrive pre-enabled and badged" do
    @session.update!(segment: "meccanica", suggested_criticalities: [ 9 ])
    visit setup_presale_session_path(@session)

    row = find("li", text: "Indicata dal prospect")
    assert row.find("input[type='checkbox']").checked?
    assert_selector "li input[type='checkbox']:checked", count: 1
  end
end
