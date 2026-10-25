require "test_helper"

class PresentationAssetsControllerTest < ActionDispatch::IntegrationTest
  ASSETS_DIR = Rails.root.join("content", "assets")

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

  test "serves a shared intro bitmap" do
    sign_in
    get presentation_asset_path(dir: "intro", filename: "Intro-step1.png")

    assert_response :success
    assert_equal "image/png", response.media_type
  end

  test "serves a minivideo as video/mp4" do
    sign_in
    with_video("C92-step1.mp4") do
      get presentation_asset_path(dir: "criticalities", filename: "C92-step1.mp4")

      assert_response :success
      assert_equal "video/mp4", response.media_type
      assert_equal 1000, response.body.bytesize
      assert_equal "bytes", response.headers["Accept-Ranges"]
      # strong (not W/) validator — required for Chrome to cache 206 video ranges
      assert_match(/\A"[0-9a-f]+-[0-9a-f]+"\z/, response.headers["ETag"])
    end
  end

  test "answers a Range request with 206 Partial Content" do
    sign_in
    with_video("C92-step2.mp4") do
      get presentation_asset_path(dir: "criticalities", filename: "C92-step2.mp4"),
          headers: { "Range" => "bytes=0-99" }

      assert_response :partial_content
      assert_equal "bytes 0-99/1000", response.headers["Content-Range"]
      assert_equal "video/mp4", response.media_type
      assert_equal 100, response.body.bytesize
    end
  end

  test "answers an unsatisfiable Range with 416" do
    sign_in
    with_video("C92-step3.mp4") do
      get presentation_asset_path(dir: "criticalities", filename: "C92-step3.mp4"),
          headers: { "Range" => "bytes=5000-6000" }

      assert_response 416
    end
  end

  test "assets are cached long-term by the browser (versioned URLs)" do
    sign_in
    get presentation_asset_path(dir: "criticalities", filename: "C01-step1.png")

    cache_control = response.headers["Cache-Control"]
    assert_includes cache_control, "max-age=31536000"
    assert_includes cache_control, "immutable"
    assert_includes cache_control, "private"
  end

  test "does not route other extensions such as a source .mov" do
    sign_in
    get "/presentation_assets/criticalities/C04-step3.mov"

    assert_response :not_found
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

  private
    # A throwaway 1000-byte file under content/assets/criticalities/ — the
    # controller serves bytes, it doesn't decode the video. Uses a fictitious
    # criticality (C92) so it never collides with real content; each test uses
    # its own step file since tests run in parallel processes.
    def with_video(filename)
      path = ASSETS_DIR.join("criticalities", filename)
      File.binwrite(path, "x" * 1000)
      yield
    ensure
      FileUtils.rm_f(path)
    end
end
