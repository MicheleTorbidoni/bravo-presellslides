# Builds calendar artifacts for a session's optional follow-up appointment:
# a downloadable .ics (VCALENDAR/VEVENT) and an "Add to Google Calendar" URL.
# Reused by the public recap page, the .ics download endpoint, and the mailer.
# All instants are emitted in UTC so any client converts to its own zone.
module AppointmentCalendar
  module_function

  DURATION = 30.minutes

  def ics(session)
    return nil unless session.appointment?

    starts = session.appointment_at.utc
    ends = (session.appointment_at + DURATION).utc

    [
      "BEGIN:VCALENDAR",
      "VERSION:2.0",
      "PRODID:-//Bravo Manufacturing//Pre-Sale Tool//IT",
      "CALSCALE:GREGORIAN",
      "METHOD:PUBLISH",
      "BEGIN:VEVENT",
      "UID:#{uid(session)}",
      "DTSTAMP:#{format_utc(Time.now.utc)}",
      "DTSTART:#{format_utc(starts)}",
      "DTEND:#{format_utc(ends)}",
      "SUMMARY:#{escape(title(session))}",
      "DESCRIPTION:#{escape(description(session))}",
      "LOCATION:#{escape(session.appointment_location.to_s)}",
      "END:VEVENT",
      "END:VCALENDAR"
    ].join("\r\n") + "\r\n"
  end

  def google_url(session)
    return nil unless session.appointment?

    starts = session.appointment_at.utc
    ends = (session.appointment_at + DURATION).utc
    params = {
      action: "TEMPLATE",
      text: title(session),
      dates: "#{format_utc(starts)}/#{format_utc(ends)}",
      details: description(session),
      location: session.appointment_location.to_s
    }
    "https://calendar.google.com/calendar/render?#{params.to_query}"
  end

  def title(session)
    company = session.company_name.presence || "Bravo Manufacturing"
    "Appuntamento con Bravo Manufacturing — #{company}"
  end

  def description(session)
    parts = []
    parts << "Commerciale: #{session.appointment_sales_name}" if session.appointment_sales_name.present?
    parts << "Luogo: #{session.appointment_location}" if session.appointment_location.present?
    parts.join("\n")
  end

  def uid(session)
    "presale-#{session.id}-#{session.public_token}@bravomanufacturing"
  end

  def format_utc(time)
    time.strftime("%Y%m%dT%H%M%SZ")
  end

  # iCalendar TEXT escaping: backslash, semicolon, comma, and newlines.
  def escape(text)
    text.to_s
        .gsub("\\", "\\\\\\\\")
        .gsub(";", "\\;")
        .gsub(",", "\\,")
        .gsub("\n", "\\n")
  end
end
