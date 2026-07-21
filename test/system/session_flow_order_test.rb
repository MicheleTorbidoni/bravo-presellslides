require "application_system_test_case"

# M17 (revised) — Fase 6: end-to-end acceptance test for the reordered flow.
# Setup is now shown twice: "light" right after creation (segment, criticality
# optional) routing into Questionario A, then "full" again after it (every
# section, criticality required) routing into the presentation. This way a
# session created outside the app's own "Nuova sessione" button (HubSpot
# webhook, the HubSpot simulator) also always passes through the questionnaire —
# every entry point lands on the same /setup, which decides light vs full from
# the session's own state.
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

  test "create -> Setup (light) -> Questionario A -> Setup (full) -> Present -> Chiusura -> Questionario B -> Debrief" do
    react_click "Nuova sessione"
    # Match on path shape rather than looking up the latest session by
    # created_at: system tests hit a real server, and two sessions created in the
    # same second (this one + fixtures) would make "last by created_at" ambiguous.
    assert_current_path %r{\A/presale_sessions/\d+/setup\z}, wait: 5
    session = PresaleSession.find(current_path[%r{/presale_sessions/(\d+)/setup}, 1])

    # Light pass: only the segment is needed. Picking it auto-selects the whole
    # criticality subset, but that's not required to proceed here.
    assert_no_text "Mostra l'introduzione"
    react_click "Meccanica"
    react_click "Avanti"
    assert_current_path profiling_presale_session_path(session), wait: 5

    # Complete the decision tree so "Avanti" enables (phase-1 extras never gate it).
    answer "Human Only", "Sì"
    answer "gestita", "Excel o carta"
    answer "Gestite le Distinte", "Sì"
    answer "Che tipo di Distinta", "Semplice (1 livello)"
    assert_button "Avanti", disabled: false
    react_click "Avanti"

    # Full pass: everything from the light pass is already in place (segment,
    # default criticality selection); the advanced sections are now visible.
    assert_current_path setup_presale_session_path(session), wait: 5
    assert_text "Mostra l'introduzione"
    react_click "Avanti"
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
