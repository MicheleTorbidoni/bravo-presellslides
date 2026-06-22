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
  end

  test "returns not found for an unknown token" do
    get public_recap_path(token: "does-not-exist")
    assert_response :not_found
  end
end
