require "test_helper"

class PresaleRecapMailerTest < ActionMailer::TestCase
  test "recap builds with recipient, default sender, subject, body and the page link" do
    session = PresaleSession.new(company_name: "Acme Spa")
    mail = PresaleRecapMailer.recap(
      session, to: "prospect@acme.it", body: "Corpo del recap",
      url: "https://app.example/r/tok123"
    )

    assert_equal [ "prospect@acme.it" ], mail.to
    assert_equal [ "loredana.mosca@antos.it" ], mail.from
    assert_match "Acme Spa", mail.subject
    assert_match "Corpo del recap", mail.text_part.body.to_s
    assert_match "Corpo del recap", mail.html_part.body.to_s
    # The cover email links to the prospect's public recap page.
    assert_match "https://app.example/r/tok123", mail.text_part.body.to_s
    assert_match "https://app.example/r/tok123", mail.html_part.body.to_s
  end

  test "the sender is configurable via RECAP_MAIL_FROM" do
    session = PresaleSession.new(company_name: "Acme")
    ENV["RECAP_MAIL_FROM"] = "custom@antos.it"
    mail = PresaleRecapMailer.recap(session, to: "prospect@acme.it", body: "x", url: "https://app.example/r/t")

    assert_equal [ "custom@antos.it" ], mail.from
  ensure
    ENV.delete("RECAP_MAIL_FROM")
  end
end
