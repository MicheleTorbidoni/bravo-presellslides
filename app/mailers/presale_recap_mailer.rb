# Sends the prospect a short cover email that links to their public recap page.
# The body is the exact cover text the operator reviewed/edited in the debrief
# screen (passed in); the template appends a button to `url` (the token-gated page).
# The sender is configurable via the RECAP_MAIL_FROM env var (default loredana.mosca@antos.it).
class PresaleRecapMailer < ApplicationMailer
  def recap(session, to:, body:, url:)
    @session = session
    @body = body
    @url = url
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
