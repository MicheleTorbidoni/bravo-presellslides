# Sends the prospect the recap of a pre-sale call. The body is the exact text the
# operator reviewed/edited in the debrief screen (passed in), so the email mirrors
# what they saw — the mailer does not regenerate it. The sender is configurable via
# the RECAP_MAIL_FROM env var (default loredana.mosca@antos.it).
class PresaleRecapMailer < ApplicationMailer
  def recap(session, to:, body:)
    @session = session
    @body = body
    company = session.company_name.presence || "il prospect"

    mail(
      to: to,
      from: recap_from,
      subject: "Recap incontro — #{company}"
    )
  end

  private
    def recap_from
      ENV.fetch("RECAP_MAIL_FROM", "loredana.mosca@antos.it")
    end
end
