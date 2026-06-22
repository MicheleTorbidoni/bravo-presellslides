require "test_helper"

class PublicRecapsControllerTest < ActionDispatch::IntegrationTest
  test "renders the public recap page for a valid token without authentication" do
    session = users(:one).presale_sessions.create!(
      company_name: "Acme Spa", contact_name: "Mario Rossi",
      segment: "meccanica", operational_profile: "ho-excel-bom-bom1",
      discussed_criticalities: [ 1 ],
      captured_questions: [
        { id: "q1", text: "Quante macchine?", criticality_id: 1, slide_id: nil, asked_at: "2026-06-20T10:00:00Z" }
      ]
    )
    session.ensure_public_token!

    # No sign-in: the page must be reachable by the prospect with just the token.
    get public_recap_path(token: session.public_token)
    assert_response :success

    props = JSON.parse(CGI.unescapeHTML(response.body[/data-page="([^"]*)"/, 1]))["props"]
    assert_equal "Acme Spa", props.dig("session", "company_name")
    assert_equal "Mario Rossi", props.dig("session", "contact_name")
    assert_includes props["topics"], "Tempi di produzione non raccolti"
    assert_includes props["questions"], "Quante macchine?"
    # The resolved subset carries the discussed flag and a context-resolved video URL.
    discussed = props["criticalities"].find { |c| c["id"] == 1 }
    assert discussed["discussed"]
    expected_url = ContentConfig.video_url_for(
      criticality_id: 1, segment: "meccanica", operational_profile: "ho-excel-bom-bom1"
    )
    assert_equal expected_url, discussed["video_url"]
    # M9: each criticality also carries an embeddable URL derived from video_url.
    assert_equal VideoEmbed.url(expected_url), discussed["embed_url"]
    assert_includes discussed["embed_url"], "youtube-nocookie.com/embed/"
  end

  test "returns not found for an unknown token" do
    get public_recap_path(token: "does-not-exist")
    assert_response :not_found
  end

  test "exposes the appointment payload when set, nil otherwise" do
    session = users(:one).presale_sessions.create!(company_name: "Acme")
    session.ensure_public_token!

    get public_recap_path(token: session.public_token)
    props = JSON.parse(CGI.unescapeHTML(response.body[/data-page="([^"]*)"/, 1]))["props"]
    assert_nil props["appointment"]

    session.update!(
      appointment_at: Time.zone.parse("2026-07-01 15:00"),
      appointment_sales_name: "Giulia Bianchi",
      appointment_location: "Meet"
    )
    get public_recap_path(token: session.public_token)
    props = JSON.parse(CGI.unescapeHTML(response.body[/data-page="([^"]*)"/, 1]))["props"]
    assert_equal "01/07/2026 alle 15:00", props.dig("appointment", "display")
    assert_equal "Giulia Bianchi", props.dig("appointment", "sales_name")
    assert_includes props.dig("appointment", "ics_url"), "/r/#{session.public_token}/calendar.ics"
    assert_includes props.dig("appointment", "google_url"), "calendar.google.com"
  end

  test "calendar serves a downloadable .ics without authentication" do
    session = users(:one).presale_sessions.create!(company_name: "Acme")
    session.ensure_public_token!
    session.update!(appointment_at: Time.zone.parse("2026-07-01 15:00"))

    get public_recap_calendar_path(token: session.public_token)
    assert_response :success
    assert_equal "text/calendar", response.media_type
    assert_includes response.body, "BEGIN:VEVENT"
  end

  test "calendar returns not found when there is no appointment" do
    session = users(:one).presale_sessions.create!(company_name: "Acme")
    session.ensure_public_token!

    get public_recap_calendar_path(token: session.public_token)
    assert_response :not_found
  end
end
