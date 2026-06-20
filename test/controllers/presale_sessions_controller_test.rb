require "test_helper"

class PresaleSessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @password = "password" # matches test/fixtures/users.yml
  end

  def sign_in
    post login_path, params: { email: @user.email, password: @password }
  end

  test "unauthenticated users are redirected to login" do
    get presale_sessions_path
    assert_redirected_to login_path
  end

  test "authenticated users can list their sessions" do
    sign_in
    get presale_sessions_path
    assert_response :success
  end

  test "creating a session adds a record and redirects into the setup flow" do
    sign_in

    assert_difference -> { @user.presale_sessions.count }, 1 do
      post presale_sessions_path
    end

    assert_redirected_to setup_presale_session_path(@user.presale_sessions.order(:created_at).last)
  end

  test "setup, profiling and result pages render for the owner" do
    sign_in
    session = presale_sessions(:one)

    get setup_presale_session_path(session)
    assert_response :success

    get profiling_presale_session_path(session)
    assert_response :success

    get result_presale_session_path(session)
    assert_response :success
  end

  test "the flow pages require authentication" do
    session = presale_sessions(:one)

    get setup_presale_session_path(session)
    assert_redirected_to login_path
  end

  test "result renders for a session with a mapped segment and profile" do
    sign_in
    session = presale_sessions(:one)
    session.update!(segment: "meccanica", operational_profile: "ho-excel-bom-bom1")

    get result_presale_session_path(session)
    assert_response :success
  end

  test "a user cannot open another user's session flow" do
    sign_in
    other_session = users(:two).presale_sessions.create!

    get setup_presale_session_path(other_session)
    assert_response :not_found
  end

  test "present renders for a profiled session with a mapped segment and profile" do
    sign_in
    session = presale_sessions(:one)
    session.update!(segment: "meccanica", operational_profile: "ho-excel-bom-bom1")

    get present_presale_session_path(session)
    assert_response :success
  end

  test "present renders in the fallback case with no mapping" do
    sign_in
    session = presale_sessions(:one)
    session.update!(segment: "alimentare", operational_profile: "unmapped-profile")

    get present_presale_session_path(session)
    assert_response :success
  end

  test "present hands over the slide definitions and the session segment" do
    sign_in
    session = presale_sessions(:one)
    session.update!(segment: "meccanica", operational_profile: "ho-excel-bom-bom1")

    get present_presale_session_path(session)
    assert_response :success
    # No Minitest props helper ships with the gem; the initial page embeds the
    # Inertia payload (HTML-escaped JSON) in the root element's data-page attribute.
    page_json = response.body[/data-page="([^"]*)"/, 1]
    props = JSON.parse(CGI.unescapeHTML(page_json))["props"]

    assert_equal "meccanica", props.dig("session", "segment")
    # Steps are discovered file-driven from content/assets/criticalities/, keyed
    # by criticality id; each step carries its resolved phase image URLs.
    assert props["stepsByCriticality"].key?("1")
    assert_equal "C01-step1", props.dig("stepsByCriticality", "1", 0, "id")
    assert(props.dig("stepsByCriticality", "1", 0, "phases").first.include?("C01-step1.png"))
    # The intro flow precedes the hub, shared across segments/profiles.
    assert_equal "Intro-step1", props.dig("introSteps", 0, "id")
    assert(props.dig("introSteps", 0, "phases").first.include?("intro/Intro-step1.png"))
    assert_equal [], props["capturedQuestions"]
  end

  test "debrief renders the summary, enriched questions and a generated recap body" do
    sign_in
    session = presale_sessions(:one)
    session.update!(
      company_name: "Acme Spa", contact_name: "Mario Rossi",
      segment: "meccanica", operational_profile: "ho-excel-bom-bom1",
      discussed_criticalities: [ 1 ], status: "closed",
      captured_questions: [
        { id: "q1", text: "Domanda?", criticality_id: 1, slide_id: "C01-step1", asked_at: "2026-06-20T10:00:00Z" },
        { id: "q2", text: "Generica?", criticality_id: nil, slide_id: nil, asked_at: "2026-06-20T10:05:00Z" }
      ]
    )

    get debrief_presale_session_path(session)
    assert_response :success
    props = JSON.parse(CGI.unescapeHTML(response.body[/data-page="([^"]*)"/, 1]))["props"]

    assert_equal "meccanica", props.dig("session", "segment")
    assert_equal "closed", props.dig("session", "status")
    assert_includes props["discussedCriticalities"], "Tempi di produzione non raccolti"
    # captured questions are enriched with the criticality label ("Generale" if none)
    assert_equal "Tempi di produzione non raccolti", props.dig("capturedQuestions", 0, "criticality_label")
    assert_equal "Generale", props.dig("capturedQuestions", 1, "criticality_label")
    # the generated body includes the deep-dive video links for hub themes with a URL
    assert_includes props["defaultRecapBody"], "Approfondimenti video:"
    expected_url = ContentConfig.video_url_for(
      criticality_id: 1, segment: "meccanica", operational_profile: "ho-excel-bom-bom1"
    )
    assert_includes props["defaultRecapBody"], expected_url
  end

  test "recap sends the email, marks the session recap_sent and redirects to the debrief" do
    sign_in
    session = presale_sessions(:one)
    session.update!(company_name: "Acme", status: "closed")

    assert_emails 1 do
      post recap_presale_session_path(session),
           params: { recipient: "prospect@acme.it", body: "Ciao, ecco il recap." }
    end

    assert_redirected_to debrief_presale_session_path(session)
    assert_equal "recap_sent", session.reload.status
    mail = ActionMailer::Base.deliveries.last
    assert_equal [ "prospect@acme.it" ], mail.to
    assert_equal [ "loredana.mosca@antos.it" ], mail.from
  end

  test "recap with an invalid recipient does not send and keeps the status" do
    sign_in
    session = presale_sessions(:one)
    session.update!(status: "closed")

    assert_no_emails do
      post recap_presale_session_path(session),
           params: { recipient: "not-an-email", body: "Ciao" }
    end

    assert_response :redirect
    assert_equal "closed", session.reload.status
  end

  test "recap with an empty body does not send" do
    sign_in
    session = presale_sessions(:one)

    assert_no_emails do
      post recap_presale_session_path(session),
           params: { recipient: "prospect@acme.it", body: "   " }
    end

    assert_equal "in_progress", session.reload.status
  end

  test "a user cannot debrief or send a recap for another user's session" do
    sign_in
    other = users(:two).presale_sessions.create!

    get debrief_presale_session_path(other)
    assert_response :not_found

    post recap_presale_session_path(other), params: { recipient: "p@acme.it", body: "x" }
    assert_response :not_found
  end

  test "update persists captured questions via the auto-save endpoint" do
    sign_in
    session = presale_sessions(:one)

    question = {
      id: "q_abc123",
      text: "Quanto tempo richiede l'onboarding?",
      criticality_id: 1,
      slide_id: "crit1-slide2",
      asked_at: "2026-06-16T10:00:00Z"
    }

    patch presale_session_path(session),
          params: { captured_questions: [ question ] },
          as: :json

    assert_response :success
    stored = session.reload.captured_questions
    assert_equal 1, stored.length
    assert_equal "Quanto tempo richiede l'onboarding?", stored.first["text"]
    assert_equal 1, stored.first["criticality_id"]
    assert_equal "crit1-slide2", stored.first["slide_id"]
    assert_equal "q_abc123", stored.first["id"]
  end

  test "present requires authentication" do
    session = presale_sessions(:one)

    get present_presale_session_path(session)
    assert_redirected_to login_path
  end

  test "a user cannot open another user's present surface" do
    sign_in
    other_session = users(:two).presale_sessions.create!

    get present_presale_session_path(other_session)
    assert_response :not_found
  end

  test "update persists fields via the auto-save endpoint and returns ok" do
    sign_in
    session = presale_sessions(:one)

    patch presale_session_path(session), params: {
      company_name: "Nuova Azienda",
      segment: "elettronica",
      discussed_criticalities: [ 2, 7 ]
    }

    assert_response :success
    session.reload
    assert_equal "Nuova Azienda", session.company_name
    assert_equal "elettronica", session.segment
    assert_equal [ 2, 7 ], session.discussed_criticalities
  end

  test "update accepts a flat JSON body (matching the frontend auto-save)" do
    sign_in
    session = presale_sessions(:one)

    patch presale_session_path(session),
          params: { company_name: "JSON Co", discussed_criticalities: [ 4 ] },
          as: :json

    assert_response :success
    session.reload
    assert_equal "JSON Co", session.company_name
    assert_equal [ 4 ], session.discussed_criticalities
  end

  test "a user cannot update another user's session" do
    sign_in
    other_session = users(:two).presale_sessions.create!

    patch presale_session_path(other_session), params: { company_name: "Hack" }

    assert_response :not_found
    assert_nil other_session.reload.company_name
  end
end
