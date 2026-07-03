require "application_system_test_case"

# M16 — Fase 5: conditional-visibility fields (visible_if), the auto-summed
# "Totale persone" with a manual override, and light inline validation on numeric
# fields. Builds on the M15 questionnaire framework.
class QuestionnaireConditionalsTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    @session = presale_sessions(:one)
    @session.update!(
      company_name: "Acme Spa", segment: "meccanica",
      operational_profile: nil, qualification_answers: {}
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
    set_value(find("input[name='#{field}'], ##{field}", match: :first), value)
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

  # Clicks an option (checkbox or radio) within the question whose text contains the
  # fragment — scopes the click so shared option labels (e.g. "Altro", "Sì") stay
  # unambiguous.
  def choose_within(question_fragment, option)
    fs = find("fieldset", text: question_fragment)
    page.execute_script("arguments[0].click()", fs.find("label", text: option).find("input"))
  end

  test "conditional fields appear, hide, and keep their value" do
    visit profiling_presale_session_path(@session)

    # Detail fields are hidden until their guard is satisfied.
    assert_no_selector "#qf-contact_role_other"
    assert_no_selector "#qf-subcontract_turnover_percentage"

    # Ticking "Altro" in the roles reveals the free-text detail.
    choose_within "Di cosa si occupa", "Altro"
    assert_selector "#qf-contact_role_other"

    # "Conto terzi = Sì" reveals the percentage; fill it.
    choose_within "conto terzi", "Sì"
    assert_selector "#qf-subcontract_turnover_percentage"
    react_fill "qf-subcontract_turnover_percentage", "30"

    # Switching to "No" hides it; the value is retained, not cleared.
    choose_within "conto terzi", "No"
    assert_no_selector "#qf-subcontract_turnover_percentage"
    choose_within "conto terzi", "Sì"
    assert_equal "30", find("#qf-subcontract_turnover_percentage").value
    page.save_screenshot("tmp/screenshots/m16-conditionals.png")
  end

  test "software-name field is gated on the criticality answer d3 = MRP" do
    visit profiling_presale_session_path(@session)

    assert_no_selector "#qf-production_management_software_name"
    choose_within "gestita", "MRP (o ERP)"
    assert_selector "#qf-production_management_software_name"
    choose_within "gestita", "Excel o carta"
    assert_no_selector "#qf-production_management_software_name"
  end

  test "totale persone auto-sums the counts, with a manual override that wins until cleared" do
    visit profiling_presale_session_path(@session)

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
    page.save_screenshot("tmp/screenshots/m16-autosum.png")
  end

  test "numeric fields show inline, non-blocking validation" do
    visit profiling_presale_session_path(@session)

    react_fill "qf-production_operators_count", "-1"
    assert_text "Inserisci un valore maggiore o uguale a 0."

    choose_within "conto terzi", "Sì"
    react_fill "qf-subcontract_turnover_percentage", "150"
    assert_text "Inserisci un valore tra 0 e 100."

    # Validation is non-blocking: the criticality gate still works independently.
    choose_within "Human Only", "Sì"
    choose_within "gestita", "Excel o carta"
    choose_within "Gestite le Distinte", "No"
    assert_button "Avanti", disabled: false
  end
end
