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

  test "creating a session adds a record and redirects to the index" do
    sign_in

    assert_difference -> { @user.presale_sessions.count }, 1 do
      post presale_sessions_path
    end

    assert_redirected_to presale_sessions_path
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

  test "a user cannot update another user's session" do
    sign_in
    other_session = users(:two).presale_sessions.create!

    patch presale_session_path(other_session), params: { company_name: "Hack" }

    assert_response :not_found
    assert_nil other_session.reload.company_name
  end
end
