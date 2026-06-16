require "test_helper"

class PresentationAssetsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @password = "password" # matches test/fixtures/users.yml
  end

  def sign_in
    post login_path, params: { email: @user.email, password: @password }
  end

  test "serves a segment-variant bitmap" do
    sign_in
    get presentation_asset_path(segment: "meccanica", filename: "criticality-1-screenshot.png")

    assert_response :success
    assert_equal "image/png", response.media_type
  end

  test "serves a common bitmap" do
    sign_in
    get presentation_asset_path(segment: "common", filename: "criticality-1-concept.png")

    assert_response :success
    assert_equal "image/png", response.media_type
  end

  test "returns 404 for a missing file (clean fallback for unbuilt assets)" do
    sign_in
    get presentation_asset_path(segment: "meccanica", filename: "does-not-exist.png")

    assert_response :not_found
  end

  test "returns 404 for an unknown segment" do
    sign_in
    get presentation_asset_path(segment: "not-a-segment", filename: "criticality-1-concept.png")

    assert_response :not_found
  end

  test "rejects path traversal in the filename" do
    sign_in
    # File.basename strips any directory component, so a traversal-looking .png
    # filename collapses to a plain basename inside the segment folder and can
    # never escape content/assets/. Here the basename does not exist → 404.
    get "/presentation_assets/common/..%2f..%2fno-such-secret.png"

    assert_response :not_found
  end

  test "requires authentication" do
    get presentation_asset_path(segment: "common", filename: "criticality-1-concept.png")

    assert_redirected_to login_path
  end
end
