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

  # Variant with the optional follow-up appointment (reminder block + .ics attachment).
  def recap_with_appointment
    session = PresaleSession.new(
      id: 0,
      company_name: "Acme Spa",
      contact_name: "Mario Rossi",
      segment: "meccanica",
      public_token: "preview-token-123",
      appointment_at: Time.zone.parse("2026-07-01 15:00"),
      appointment_sales_name: "Giulia Bianchi",
      appointment_location: "Videocall Google Meet"
    )

    PresaleRecapMailer.recap(
      session,
      to: "prospect@example.com",
      body: "Ciao Mario,\n\ntrovi tutto qui sotto.\n\nA presto.",
      url: "http://localhost:3000/r/preview-token-123"
    )
  end
end
