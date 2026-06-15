require "test_helper"

class PresaleSessionTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test "an empty session can be created for a user" do
    session = @user.presale_sessions.create!

    assert session.persisted?
    assert_equal @user, session.user
  end

  test "defaults to the in_progress status" do
    session = @user.presale_sessions.create!

    assert session.in_progress?
    assert_equal "in_progress", session.status
  end

  test "discussed_criticalities defaults to an empty array" do
    session = @user.presale_sessions.create!

    assert_equal [], session.discussed_criticalities
  end

  test "exposes the three statuses as an enum" do
    assert_equal %w[ in_progress closed recap_sent ], PresaleSession.statuses.keys
  end

  test "fields are persisted on update (auto-save)" do
    session = @user.presale_sessions.create!

    session.update!(
      company_name: "Bravo Manufacturing",
      contact_name: "Loredana",
      segment: "meccanica",
      operational_profile: "profilo-1",
      discussed_criticalities: [ 1, 3, 4 ],
      status: "closed"
    )

    session.reload
    assert_equal "Bravo Manufacturing", session.company_name
    assert_equal "meccanica", session.segment
    assert_equal [ 1, 3, 4 ], session.discussed_criticalities
    assert session.closed?
  end

  test "is removed when its user is destroyed" do
    @user.presale_sessions.create!

    assert_difference -> { PresaleSession.count }, -@user.presale_sessions.count do
      @user.destroy
    end
  end
end
