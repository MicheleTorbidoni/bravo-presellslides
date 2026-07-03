require "application_system_test_case"

# M15 — Fase 5: the profiling screen now shows the decision-tree (criticality)
# questions interleaved with the sales-qualification questionnaire, grouped by
# semantic context. Criticality questions are visually distinct (accent card) and a
# toggle hides everything but them. Extra answers auto-save to qualification_answers
# and are restored on reload; they never gate the "Avanti" button.
class QuestionnaireFrameworkTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    @session = presale_sessions(:one)
    @session.update!(
      company_name: "Acme Spa", contact_name: "Mario Rossi",
      segment: "meccanica", operational_profile: nil, qualification_answers: {}
    )

    visit login_path
    react_fill "email", @user.email
    react_fill "password", "password"
    react_click "Log in"
    assert_current_path dashboard_path, wait: 5
  end

  def react_click(text)
    page.execute_script("arguments[0].click()", find("button", text: text))
  end

  def react_fill(field, value)
    input = find("input[name='#{field}'], ##{field}", match: :first)
    set_value(input, value)
  end

  def set_value(el, value)
    page.execute_script(<<~JS, el, value)
      const el = arguments[0]
      const proto = el.tagName === "TEXTAREA"
        ? window.HTMLTextAreaElement.prototype
        : window.HTMLInputElement.prototype
      const setter = Object.getOwnPropertyDescriptor(proto, "value").set
      setter.call(el, arguments[1])
      el.dispatchEvent(new Event("input", { bubbles: true }))
    JS
  end

  # Picks a single choice (radio/label) within the question whose text contains the
  # fragment. Works for both criticality radios and boolean Sì/No fields.
  def answer(question_fragment, answer_text)
    fs = find("fieldset", text: question_fragment)
    input = fs.find("label", text: answer_text).find("input")
    page.execute_script("arguments[0].click()", input)
  end

  test "grouped layout, extra fields, auto-save + restore, and the criticality-only toggle" do
    visit profiling_presale_session_path(@session)

    # Semantic groups are on screen, criticality questions interleaved.
    assert_selector "h2", text: "Interlocutore"
    assert_selector "h2", text: "Azienda"
    assert_selector "h2", text: "Produzione & macchine"
    assert_selector "legend", text: "Human Only"       # criticality (ref)
    assert_text "Fatturato annuo"                        # extra field
    page.save_screenshot("tmp/screenshots/m15-questionnaire-desktop.png")

    # Fill some extra fields (various types).
    react_fill "qf-annual_turnover_amount", "1500000"
    react_fill "qf-mes_expectations_text", "Ricontattare a settembre."
    answer "outsourcing", "Sì"                           # boolean field
    within find("fieldset", text: "Di cosa si occupa") do
      page.execute_script(
        "arguments[0].click()",
        find("label", text: "Consulente").find("input"),
      )
    end

    # Complete the criticality path so "Avanti" enables (extras never gate it).
    assert_button "Avanti", disabled: true
    answer "Human Only", "Sì"
    answer "gestita", "Excel o carta"
    answer "Gestite le Distinte", "Sì"
    answer "Che tipo di Distinta", "Semplice (1 livello)"
    assert_button "Avanti", disabled: false

    # Auto-save flushes the extras + the token profile.
    sleep 0.6
    stored = @session.reload.qualification_answers
    assert_equal 1_500_000, stored["annual_turnover_amount"]
    assert_equal "Ricontattare a settembre.", stored["mes_expectations_text"]
    assert_equal true, stored["does_outsource_work"]
    assert_equal [ "Consulente" ], stored["contact_roles"]
    assert_equal "ho-excel-bom-bom1", @session.operational_profile

    # Reload: extra values and criticality answers are restored.
    visit profiling_presale_session_path(@session)
    assert_equal "1500000", find("#qf-annual_turnover_amount").value
    assert find("fieldset", text: "Di cosa si occupa").find("label", text: "Consulente").find("input").checked?
    assert find("fieldset", text: "Human Only").find("label", text: "Sì").find("input").checked?

    # Toggle "solo criticità": extras disappear, criticality questions remain.
    within find("label", text: "Mostra solo domande per le criticità") do
      page.execute_script("arguments[0].click()", find("input"))
    end
    assert_no_text "Fatturato annuo"
    assert_selector "legend", text: "Human Only"
    page.save_screenshot("tmp/screenshots/m15-only-criticality.png")
  end

  test "renders correctly at mobile width" do
    @session.update!(qualification_answers: { "annual_turnover_amount" => 900_000 })
    page.driver.browser.manage.window.resize_to(390, 900)
    visit profiling_presale_session_path(@session)
    assert_selector "h2", text: "Interlocutore"
    assert_text "Fatturato annuo"
    page.save_screenshot("tmp/screenshots/m15-questionnaire-mobile.png")
  end
end
