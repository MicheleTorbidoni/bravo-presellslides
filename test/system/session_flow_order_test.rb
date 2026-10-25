require "application_system_test_case"

# Fase 8 — end-to-end acceptance test for the flow: Setup (everything about the
# presentation, shown once) -> Questionario A -> straight into the presentation.
# Every entry point (the app's "Nuova sessione" button, the HubSpot webhook, the
# HubSpot simulator) lands on the same /setup, so the questionnaire is always run.
class SessionFlowOrderTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)

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

  test "create -> Setup -> Questionario A -> Present -> Chiusura -> Questionario B -> Debrief" do
    react_click "Nuova sessione"
    # Match on path shape rather than looking up the latest session by
    # created_at: system tests hit a real server, and two sessions created in the
    # same second (this one + fixtures) would make "last by created_at" ambiguous.
    assert_current_path %r{\A/presale_sessions/\d+/setup\z}, wait: 5
    session = PresaleSession.find(current_path[%r{/presale_sessions/(\d+)/setup}, 1])

    # Setup holds the whole configuration: segment + at least one criticality.
    assert_text "Mostra l'introduzione"
    react_click "Meccanica"
    input = find("li", text: "Tempi di produzione non raccolti").find("input[type='checkbox']")
    page.execute_script("arguments[0].click()", input)
    react_click "Avanti"
    assert_current_path profiling_presale_session_path(session), wait: 5

    # Complete the decision tree so "Avanti" enables (phase-1 extras never gate it).
    answer "Human Only", "Sì"
    answer "gestita", "Excel o carta"
    answer "Gestite le Distinte", "Sì"
    answer "Che tipo di Distinta", "Semplice (1 livello)"
    assert_button "Avanti", disabled: false
    react_click "Avanti"

    # No second Setup pass: profiling leads straight into the presentation.
    assert_current_path present_presale_session_path(session), wait: 5

    # The C shortcut jumps to the closing page from any view (intro/hub/flow) —
    # no need to complete a criticality to reach it.
    page.execute_script(
      "window.dispatchEvent(new KeyboardEvent('keydown', { key: 'c', bubbles: true }))"
    )
    assert_text "Grazie"

    react_click "Completa scheda"
    assert_current_path qualification_presale_session_path(session), wait: 5
    assert_selector "h2", text: "Azienda"

    react_click "Vai al riepilogo"
    assert_current_path debrief_presale_session_path(session), wait: 5
    assert_equal "closed", session.reload.status
  end
end
