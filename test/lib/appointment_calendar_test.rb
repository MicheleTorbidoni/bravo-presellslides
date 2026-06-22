require "test_helper"

class AppointmentCalendarTest < ActiveSupport::TestCase
  def session_with_appointment
    PresaleSession.new(
      id: 7,
      company_name: "Acme Spa",
      public_token: "tok123",
      appointment_at: Time.zone.parse("2026-07-01 15:00"),
      appointment_sales_name: "Giulia Bianchi",
      appointment_location: "Videocall, Meet"
    )
  end

  test "ics returns a VEVENT with start, summary, location and a stable uid" do
    ics = AppointmentCalendar.ics(session_with_appointment)

    assert_includes ics, "BEGIN:VEVENT"
    assert_includes ics, "END:VEVENT"
    # 15:00 Rome in July (DST, +02:00) → 13:00 UTC.
    assert_includes ics, "DTSTART:20260701T130000Z"
    assert_includes ics, "DTEND:20260701T133000Z"
    assert_includes ics, "SUMMARY:Appuntamento con Bravo Manufacturing — Acme Spa"
    assert_includes ics, "Giulia Bianchi"
    # Commas in TEXT values must be escaped per RFC 5545.
    assert_includes ics, "LOCATION:Videocall\\, Meet"
    assert_includes ics, "UID:presale-7-tok123@bravomanufacturing"
  end

  test "google_url carries the event title and UTC dates" do
    url = AppointmentCalendar.google_url(session_with_appointment)

    assert_includes url, "calendar.google.com"
    assert_includes url, "20260701T130000Z%2F20260701T133000Z"
    assert_includes url, "Acme+Spa"
  end

  test "returns nil when there is no appointment" do
    session = PresaleSession.new(company_name: "Acme")

    assert_nil AppointmentCalendar.ics(session)
    assert_nil AppointmentCalendar.google_url(session)
  end
end
