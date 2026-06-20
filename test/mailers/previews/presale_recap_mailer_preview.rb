# Preview at /rails/mailers/presale_recap_mailer/recap (development only).
class PresaleRecapMailerPreview < ActionMailer::Preview
  def recap
    session = PresaleSession.new(
      company_name: "Acme Spa",
      contact_name: "Mario Rossi",
      segment: "meccanica"
    )
    body = <<~TEXT
      Ciao Mario,

      grazie per il tempo dedicato. Di seguito un riepilogo di quanto visto insieme per Acme Spa.

      Temi affrontati:
      - Tempi di produzione non raccolti

      Approfondimenti video:
      - Tempi di produzione non raccolti: https://www.youtube.com/watch?v=PLACEHOLDER-C01

      A presto,
      il team Bravo Manufacturing
    TEXT

    PresaleRecapMailer.recap(session, to: "prospect@example.com", body: body)
  end
end
