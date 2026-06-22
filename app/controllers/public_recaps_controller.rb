# Public, login-less recap page for the prospect. The unguessable token in the
# path is the only credential — the contact is already identified upstream (CRM),
# so we don't force an account. The page is marked noindex and is excluded from
# robots/sitemap so it stays private despite being publicly reachable.
class PublicRecapsController < ApplicationController
  allow_unauthenticated_access

  def show
    session = PresaleSession.find_by!(public_token: params[:token])

    render inertia: "PublicRecap", props: {
      session: {
        company_name: session.company_name,
        contact_name: session.contact_name
      },
      topics: discussed_criticality_labels(session),
      questions: session.captured_questions.map { |q| q["text"] }.compact_blank,
      criticalities: recap_criticalities(session),
      appointment: appointment_payload(session)
    }
  end

  # The follow-up appointment as a downloadable .ics file (same token gate, no login).
  def calendar
    session = PresaleSession.find_by!(public_token: params[:token])
    return head(:not_found) unless session.appointment?

    send_data AppointmentCalendar.ics(session),
      type: "text/calendar",
      filename: "appuntamento.ics",
      disposition: "attachment"
  end

  private
    # nil when no appointment is set, so the page simply omits the reminder block.
    def appointment_payload(session)
      return nil unless session.appointment?

      {
        display: session.appointment_at.in_time_zone("Europe/Rome").strftime("%d/%m/%Y alle %H:%M"),
        sales_name: session.appointment_sales_name,
        location: session.appointment_location,
        ics_url: public_recap_calendar_url(token: session.public_token),
        google_url: AppointmentCalendar.google_url(session)
      }
    end

    # Labels of the criticalities actually discussed, in the order they were marked.
    def discussed_criticality_labels(session)
      by_id = ContentConfig.criticalities.index_by { |c| c[:id] }
      session.discussed_criticalities.filter_map { |id| by_id[id]&.dig(:label) }
    end

    # The prospect's resolved criticality subset (or the full list of 13 as the same
    # predictable fallback used elsewhere), each carrying whether it was discussed
    # and its context-resolved deep-dive video URL. M8 renders the discussed ones
    # with a video as simple links; M9 turns this into embeds + subset exploration.
    def recap_criticalities(session)
      relevant = ContentConfig.criticalities_for(
        segment: session.segment,
        operational_profile: session.operational_profile
      )
      relevant = ContentConfig.criticalities if relevant.empty?
      discussed = session.discussed_criticalities

      relevant.map do |c|
        {
          id: c[:id],
          label: c[:label],
          discussed: discussed.include?(c[:id]),
          video_url: ContentConfig.video_url_for(
            criticality_id: c[:id],
            segment: session.segment,
            operational_profile: session.operational_profile
          )
        }
      end
    end
end
