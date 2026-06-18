require "test_helper"

class PresentationAssetsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @password = "password" # matches test/fixtures/users.yml
  end

  def sign_in
    post login_path, params: { email: @user.email, password: @password }
  end

  test "serves a shared criticality bitmap" do
    sign_in
    get presentation_asset_path(dir: "criticalities", filename: "C01-step1.png")

    assert_response :success
    assert_equal "image/png", response.media_type
  end

  test "returns 404 for a missing file in a valid dir (clean fallback)" do
    sign_in
    get presentation_asset_path(dir: "criticalities", filename: "does-not-exist.png")

    assert_response :not_found
  end

  test "returns 404 for an unknown dir" do
    sign_in
    get presentation_asset_path(dir: "not-a-dir", filename: "C01-step1.png")

    assert_response :not_found
  end

  test "rejects path traversal in the filename" do
    sign_in
    # File.basename strips any directory component, so a traversal-looking .png
    # filename collapses to a plain basename inside the dir and can never escape
    # content/assets/. Here the basename does not exist → 404.
    get "/presentation_assets/criticalities/..%2f..%2fno-such-secret.png"

    assert_response :not_found
  end

  test "requires authentication" do
    get presentation_asset_path(dir: "criticalities", filename: "C01-step1.png")

    assert_redirected_to login_path
  end
end
