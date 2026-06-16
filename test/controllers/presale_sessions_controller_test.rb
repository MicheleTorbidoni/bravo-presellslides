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
