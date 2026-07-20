require "application_system_test_case"

# M14: adding criticalities from another segment in the Setup, and their behaviour
# downstream (persistence, per-segment reset, appearance in the prospect's hub with
# origin-segment slides). The "add from another segment" panel only renders on the
# "full" Setup pass (after Questionario A — see setup_stages_test.rb), so every
# session here is pre-profiled.
class SetupExtraCriticalitiesTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    @session = presale_sessions(:one)
    @session.update!(
      company_name: "Acme Spa", contact_name: "Mario Rossi",
      segment: "meccanica", operational_profile: "ho-excel-bom-bom1"
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

  test "add, badge, persistence, and reset of extra criticalities" do
    visit setup_presale_session_path(@session)
    assert_text "Aggiungi criticità da un altro segmento"
    page.save_screenshot("tmp/screenshots/m14-setup-panel.png")

    # Pick elettronica in the picker (native select).
    find("select[aria-label='Scegli un altro segmento']").find("option", text: "Elettronica").select_option

    # 3 is already in meccanica's subset → not addable; 9 is addable.
    assert_text "Già presente"
    page.execute_script("document.querySelector('select[aria-label=\"Scegli un altro segmento\"]').scrollIntoView()")
    page.save_screenshot("tmp/screenshots/m14-picker-open.png")
    within all("li").find { |li| li.text.include?("Segniamo ancora tutto") } do
      react_click "Aggiungi"
    end

    # The extra now appears in the main list with an Elettronica origin badge + remove X.
    assert_selector "li", text: "Segniamo ancora tutto"
    assert_selector ".badge", text: "Elettronica"
    assert_selector "button[aria-label*='Rimuovi']"
    page.save_screenshot("tmp/screenshots/m14-extra-added.png")

    # Persisted on the session by the (debounced) auto-save.
    sleep 0.6
    assert_equal [ { "id" => 9, "segment" => "elettronica" } ],
      @session.reload.extra_criticalities

    # Reload: the extra survives.
    visit setup_presale_session_path(@session)
    assert_selector ".badge", text: "Elettronica"

    # Changing the prospect's segment clears the extras.
    react_click "Precisione"
    assert_no_selector ".badge", text: "Elettronica"
    sleep 0.6 # let the debounced auto-save flush
    assert_equal [], @session.reload.extra_criticalities
    page.save_screenshot("tmp/screenshots/m14-after-segment-reset.png")
  end

  test "setup with an extra renders correctly at mobile width" do
    @session.update!(
      selected_criticalities: [ 1, 9 ], criticalities_order: [ 9, 1 ],
      extra_criticalities: [ { id: 9, segment: "elettronica" } ]
    )
    page.driver.browser.manage.window.resize_to(390, 900)
    visit setup_presale_session_path(@session)
    assert_selector ".badge", text: "Elettronica"
    assert_text "Aggiungi criticità da un altro segmento"
    page.save_screenshot("tmp/screenshots/m14-setup-mobile.png")
  end

  test "the extra criticality appears in the hub and resolves origin-segment slides" do
    @session.update!(
      operational_profile: "ho-excel-bom-bom1",
      selected_criticalities: [ 1, 9 ],
      criticalities_order: [ 9, 1 ],
      extra_criticalities: [ { id: 9, segment: "elettronica" } ]
    )
    visit present_presale_session_path(@session)

    10.times do
      break if page.has_text?("Dove fa più difficoltà la tua azienda?", wait: 0.2)
      page.execute_script("window.dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowRight', bubbles: true }))")
    end
    assert_text "Segniamo ancora tutto su fogli Excel o carta"
    page.save_screenshot("tmp/screenshots/m14-hub-with-extra.png")

    react_click "Segniamo ancora tutto su fogli Excel o carta"
    # Its slides resolve on the origin segment (elettronica), not meccanica.
    assert_selector "img[src*='/elettronica/C09-step1']", wait: 5
    page.save_screenshot("tmp/screenshots/m14-extra-slide.png")
  end
end
