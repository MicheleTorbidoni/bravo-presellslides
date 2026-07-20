require "application_system_test_case"

# M15: the profiling screen is no longer a step-by-step wizard. All decision-tree
# questions are shown at once; questions whose branch is excluded by a given answer
# become disabled (their value is ignored by the profile walk). The operational
# profile is rebuilt from the start node along the answered branches, so the token
# string stays deterministic regardless of click order.
class ProfilingAllAtOnceTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    @session = presale_sessions(:one)
    @session.update!(
      company_name: "Acme Spa", contact_name: "Mario Rossi",
      segment: "meccanica", operational_profile: nil
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

  # Selects `answer_text` within the question whose text contains `question_fragment`.
  def answer(question_fragment, answer_text)
    fs = find("fieldset", text: question_fragment)
    input = fs.find("label", text: answer_text).find("input")
    page.execute_script("arguments[0].click()", input)
  end

  test "all questions visible, cascade-disable, and a complete profile submits" do
    visit profiling_presale_session_path(@session)

    # Every decision-tree question is on screen at once (no wizard).
    assert_selector "legend", text: "Human Only"
    assert_selector "legend", text: "IoT"
    assert_selector "legend", text: "gestita"
    assert_selector "legend", text: "Gestite le Distinte"
    assert_selector "legend", text: "Che tipo di Distinta"
    page.save_screenshot("tmp/screenshots/m15-profiling-initial.png")

    # Nothing answered yet → cannot proceed.
    assert_button "Avanti", disabled: true

    # Human Only = Sì → the IoT question (d2) is excluded from the path → disabled.
    answer "Human Only", "Sì"
    assert_selector "fieldset[disabled]", text: "IoT"
    page.save_screenshot("tmp/screenshots/m15-iot-disabled.png")

    # Complete the rest of the active path.
    answer "gestita", "Excel o carta"
    answer "Gestite le Distinte", "Sì"       # unlocks d5
    assert_no_selector "fieldset[disabled]", text: "Che tipo di Distinta"
    answer "Che tipo di Distinta", "Semplice (1 livello)"

    assert_button "Avanti", disabled: false
    react_click "Avanti"

    assert_current_path setup_presale_session_path(@session), wait: 5
    # Profile is the deterministic walk from the start, IoT token skipped.
    assert_equal "ho-excel-bom-bom1", @session.reload.operational_profile
  end

  test "changing a parent answer prunes the child branch from the token string" do
    visit profiling_presale_session_path(@session)

    answer "Human Only", "No"                 # keeps d2 (IoT) active
    answer "Avete macchine", "Sì"             # d2 — "IoT" now also appears in an extra field's options
    answer "gestita", "MRP (o ERP)"
    answer "Gestite le Distinte", "Sì"        # unlocks d5
    answer "Che tipo di Distinta", "Multilivello"

    # Now flip d4 to "No": d5 is excluded, its answer must drop out of the profile.
    answer "Gestite le Distinte", "No"
    assert_selector "fieldset[disabled]", text: "Che tipo di Distinta"

    assert_button "Avanti", disabled: false
    react_click "Avanti"

    assert_current_path setup_presale_session_path(@session), wait: 5
    assert_equal "mixed-iot-mrp-nobom", @session.reload.operational_profile
  end
end
