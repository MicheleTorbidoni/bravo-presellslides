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

  test "attaches an .ics and shows the reminder when an appointment is set" do
    session = PresaleSession.new(
      id: 1, company_name: "Acme Spa", public_token: "tok",
      appointment_at: Time.zone.parse("2026-07-01 15:00"),
      appointment_sales_name: "Giulia Bianchi"
    )
    mail = PresaleRecapMailer.recap(session, to: "p@acme.it", body: "Ciao", url: "https://app.example/r/tok")

    ics = mail.attachments["appuntamento.ics"]
    assert ics, "expected an .ics attachment"
    assert_equal "text/calendar", ics.mime_type
    assert_includes ics.body.to_s, "BEGIN:VEVENT"
    # The body mentions the appointment (Rome wall-clock).
    assert_match "01/07/2026 alle 15:00", mail.text_part.body.to_s
    assert_match "Giulia Bianchi", mail.html_part.body.to_s
  end

  test "has no .ics attachment when no appointment is set" do
    session = PresaleSession.new(company_name: "Acme")
    mail = PresaleRecapMailer.recap(session, to: "p@acme.it", body: "Ciao", url: "https://app.example/r/t")

    assert_empty mail.attachments
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
