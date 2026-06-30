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

  test "result hands over the prospect's suggested criticalities for the badge" do
    sign_in
    session = presale_sessions(:one)
    session.update!(segment: "meccanica", operational_profile: "ho-excel-bom-bom1",
      suggested_criticalities: [ 1, 3 ])

    get result_presale_session_path(session)
    assert_response :success
    props = JSON.parse(CGI.unescapeHTML(response.body[/data-page="([^"]*)"/, 1]))["props"]
    assert_equal [ 1, 3 ], props["suggested"]
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

  test "present renders in the fallback case with an unknown segment" do
    sign_in
    session = presale_sessions(:one)
    session.update!(segment: "settore-inventato", operational_profile: "ho-excel-bom-bom1")

    get present_presale_session_path(session)
    assert_response :success
    props = JSON.parse(CGI.unescapeHTML(response.body[/data-page="([^"]*)"/, 1]))["props"]
    # Unknown segment → no per-segment subset → predictable fallback to all 13.
    assert_equal false, props["prefiltered"]
    assert_equal 13, props["criticalities"].size
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

  test "present hands over the prospect's suggested criticalities for the hub badge" do
    sign_in
    session = presale_sessions(:one)
    session.update!(segment: "meccanica", suggested_criticalities: [ 1, 3 ])

    get present_presale_session_path(session)
    assert_response :success
    props = JSON.parse(CGI.unescapeHTML(response.body[/data-page="([^"]*)"/, 1]))["props"]
    assert_equal [ 1, 3 ], props["suggestedCriticalities"]
  end

  test "debrief renders the summary, enriched questions and a generated recap body" do
    sign_in
    session = presale_sessions(:one)
    session.update!(
      company_name: "Acme Spa", contact_name: "Mario Rossi",
      prospect_email: "mario.rossi@acme.it",
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
    # The prospect's email pre-fills the recap recipient field in the dialog.
    assert_equal "mario.rossi@acme.it", props.dig("session", "prospect_email")
    assert_includes props["discussedCriticalities"], "Tempi di produzione non raccolti"
    # captured questions are enriched with the criticality label ("Generale" if none)
    assert_equal "Tempi di produzione non raccolti", props.dig("capturedQuestions", 0, "criticality_label")
    assert_equal "Generale", props.dig("capturedQuestions", 1, "criticality_label")
    # The email body is now a short cover (greeting + context); the recap content
    # — themes, questions, video links — lives on the public page, not the email.
    assert_includes props["defaultRecapBody"], "Acme Spa"
    refute_includes props["defaultRecapBody"], "Approfondimenti video:"
    # No recap sent yet for this session, so there is no public link to show.
    assert_nil props["publicRecapUrl"]
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
    # Sending mints the public token, and the email links to that public page.
    assert session.public_token.present?
    mail = ActionMailer::Base.deliveries.last
    assert_equal [ "prospect@acme.it" ], mail.to
    assert_equal [ "loredana.mosca@antos.it" ], mail.from
    assert_match "/r/#{session.public_token}", mail.text_part.body.to_s
  end

  test "recap reuses the existing public token on re-send and exposes the link in the debrief" do
    sign_in
    session = presale_sessions(:one)
    session.update!(company_name: "Acme", status: "closed")

    post recap_presale_session_path(session), params: { recipient: "a@acme.it", body: "x" }
    first_token = session.reload.public_token
    assert first_token.present?

    post recap_presale_session_path(session), params: { recipient: "b@acme.it", body: "y" }
    assert_equal first_token, session.reload.public_token, "token must stay stable on re-send"

    get debrief_presale_session_path(session)
    props = JSON.parse(CGI.unescapeHTML(response.body[/data-page="([^"]*)"/, 1]))["props"]
    assert_includes props["publicRecapUrl"].to_s, "/r/#{first_token}"
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

  test "appointment fields persist via auto-save and round-trip in Rome time" do
    sign_in
    session = presale_sessions(:one)

    patch presale_session_path(session), params: {
      appointment_at: "2026-07-01T15:00",
      appointment_sales_name: "Giulia Bianchi",
      appointment_location: "Meet"
    }, as: :json
    assert_response :success

    session.reload
    # 15:00 Rome (DST) stored as 13:00 UTC.
    assert_equal "2026-07-01 13:00", session.appointment_at.utc.strftime("%Y-%m-%d %H:%M")
    assert_equal "Giulia Bianchi", session.appointment_sales_name

    get debrief_presale_session_path(session)
    props = JSON.parse(CGI.unescapeHTML(response.body[/data-page="([^"]*)"/, 1]))["props"]
    # The debrief echoes back the same Rome wall-clock for the datetime-local input.
    assert_equal "2026-07-01T15:00", props.dig("session", "appointment_at_local")
  end

  test "a user cannot update another user's session" do
    sign_in
    other_session = users(:two).presale_sessions.create!

    patch presale_session_path(other_session), params: { company_name: "Hack" }

    assert_response :not_found
    assert_nil other_session.reload.company_name
  end

  test "index hands over the contact name and resolved segment label" do
    sign_in
    session = presale_sessions(:one)
    session.update!(contact_name: "Mario Rossi", segment: "meccanica")

    get presale_sessions_path
    assert_response :success
    props = JSON.parse(CGI.unescapeHTML(response.body[/data-page="([^"]*)"/, 1]))["props"]

    row = props["sessions"].find { |s| s["id"] == session.id }
    assert_equal "Mario Rossi", row["contact_name"]
    expected_label = ContentConfig.segments.find { |s| s[:id] == "meccanica" }[:label]
    assert_equal expected_label, row["segment_label"]
  end

  test "destroy deletes the session and redirects to the archive" do
    sign_in
    session = presale_sessions(:one)

    assert_difference -> { @user.presale_sessions.count }, -1 do
      delete presale_session_path(session)
    end

    assert_redirected_to presale_sessions_path
  end

  test "a user cannot delete another user's session" do
    sign_in
    other_session = users(:two).presale_sessions.create!

    assert_no_difference -> { PresaleSession.count } do
      delete presale_session_path(other_session)
    end

    assert_response :not_found
  end

  # ----- Setup: criticality selection + intro toggle -----

  test "setup defaults the criticality selection to the whole segment subset" do
    sign_in
    session = presale_sessions(:one)
    session.update!(segment: "meccanica")

    get setup_presale_session_path(session)
    assert_response :success
    props = JSON.parse(CGI.unescapeHTML(response.body[/data-page="([^"]*)"/, 1]))["props"]

    # No suggestions and no explicit choice → every criticality of the segment.
    assert_equal [ 1, 2, 3, 4, 7, 8, 10 ], props["selectedCriticalities"].sort
    assert_equal true, props["showIntro"]
    assert_equal [], props["suggested"]
    # The per-segment map lets the client re-render the list as the segment changes.
    assert props["criticalitiesBySegment"].key?("meccanica")
  end

  test "setup defaults the selection to the prospect's suggestions when present" do
    sign_in
    session = presale_sessions(:one)
    session.update!(segment: "meccanica", suggested_criticalities: [ 3, 7 ])

    get setup_presale_session_path(session)
    props = JSON.parse(CGI.unescapeHTML(response.body[/data-page="([^"]*)"/, 1]))["props"]
    assert_equal [ 3, 7 ], props["selectedCriticalities"].sort
    assert_equal [ 3, 7 ], props["suggested"]
  end

  test "setup honours an explicit selection, clamped to the segment" do
    sign_in
    session = presale_sessions(:one)
    # 99 is not a meccanica criticality → dropped; the rest is kept.
    session.update!(segment: "meccanica", selected_criticalities: [ 1, 7, 99 ])

    get setup_presale_session_path(session)
    props = JSON.parse(CGI.unescapeHTML(response.body[/data-page="([^"]*)"/, 1]))["props"]
    assert_equal [ 1, 7 ], props["selectedCriticalities"].sort
  end

  test "present uses the operator's selected subset and the intro toggle" do
    sign_in
    session = presale_sessions(:one)
    session.update!(segment: "meccanica", operational_profile: "ho-excel-bom-bom1",
      selected_criticalities: [ 2 ], show_intro: false)

    get present_presale_session_path(session)
    assert_response :success
    props = JSON.parse(CGI.unescapeHTML(response.body[/data-page="([^"]*)"/, 1]))["props"]
    assert_equal [ 2 ], props["criticalities"].map { |c| c["id"] }
    assert_equal false, props["showIntro"]
  end

  test "result marks the discussed criticalities in the end summary" do
    sign_in
    session = presale_sessions(:one)
    session.update!(segment: "meccanica", operational_profile: "ho-excel-bom-bom1",
      selected_criticalities: [ 1, 2 ], discussed_criticalities: [ 1 ])

    get result_presale_session_path(session)
    props = JSON.parse(CGI.unescapeHTML(response.body[/data-page="([^"]*)"/, 1]))["props"]
    assert_equal [ 1, 2 ], props["criticalities"].map { |c| c["id"] }
    assert_equal [ 1 ], props["discussed"]
  end

  test "update persists the selection and intro toggle via auto-save" do
    sign_in
    session = presale_sessions(:one)

    patch presale_session_path(session),
          params: { selected_criticalities: [ 3, 8 ], show_intro: false },
          as: :json

    assert_response :success
    session.reload
    assert_equal [ 3, 8 ], session.selected_criticalities
    assert_equal false, session.show_intro
  end

  test "update accepts an explicit empty selection (operator disabled all)" do
    sign_in
    session = presale_sessions(:one)
    session.update!(selected_criticalities: [ 1, 2 ])

    patch presale_session_path(session),
          params: { selected_criticalities: [] },
          as: :json

    assert_response :success
    assert_equal [], session.reload.selected_criticalities
  end

  # ----- Setup: criticality ordering + hub toggle -----

  test "setup defaults the criticality order to the segment's default order and shows the hub" do
    sign_in
    session = presale_sessions(:one)
    session.update!(segment: "meccanica")

    get setup_presale_session_path(session)
    assert_response :success
    props = JSON.parse(CGI.unescapeHTML(response.body[/data-page="([^"]*)"/, 1]))["props"]

    default_order = ContentConfig.criticalities_for_segment(segment: "meccanica").map { |c| c[:id] }
    assert_equal default_order, props["criticalitiesOrder"]
    assert_equal true, props["showHub"]
  end

  test "setup honours a saved order, clamped to the segment and appending new ids" do
    sign_in
    session = presale_sessions(:one)
    # 99 is not a meccanica criticality → dropped; the remaining segment ids that
    # aren't in the saved order are appended in default order.
    session.update!(segment: "meccanica", criticalities_order: [ 7, 1, 99 ])

    get setup_presale_session_path(session)
    props = JSON.parse(CGI.unescapeHTML(response.body[/data-page="([^"]*)"/, 1]))["props"]

    default_order = ContentConfig.criticalities_for_segment(segment: "meccanica").map { |c| c[:id] }
    expected = [ 7, 1 ] + (default_order - [ 7, 1 ])
    assert_equal expected, props["criticalitiesOrder"]
  end

  test "present orders the criticalities by the operator's saved order and hands over showHub" do
    sign_in
    session = presale_sessions(:one)
    session.update!(segment: "meccanica", operational_profile: "ho-excel-bom-bom1",
      selected_criticalities: [ 1, 2, 3 ], criticalities_order: [ 3, 1, 2 ], show_hub: false)

    get present_presale_session_path(session)
    assert_response :success
    props = JSON.parse(CGI.unescapeHTML(response.body[/data-page="([^"]*)"/, 1]))["props"]
    assert_equal [ 3, 1, 2 ], props["criticalities"].map { |c| c["id"] }
    assert_equal false, props["showHub"]
  end

  test "update persists the criticality order and hub toggle via auto-save" do
    sign_in
    session = presale_sessions(:one)

    patch presale_session_path(session),
          params: { criticalities_order: [ 3, 1, 2 ], show_hub: false },
          as: :json

    assert_response :success
    session.reload
    assert_equal [ 3, 1, 2 ], session.criticalities_order
    assert_equal false, session.show_hub
  end
end
