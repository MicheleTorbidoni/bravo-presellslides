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

      grazie per il tempo dedicato. Ho preparato una pagina con il riepilogo di quanto visto insieme per Acme Spa e i video di approfondimento del vostro caso.

      Trovi tutto qui sotto.

      A presto,
      il team Bravo Manufacturing
    TEXT

    PresaleRecapMailer.recap(
      session,
      to: "prospect@example.com",
      body: body,
      url: "http://localhost:3000/r/preview-token-123"
    )
  end
end
