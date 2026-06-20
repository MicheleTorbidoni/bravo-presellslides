class PresaleSessionsController < ApplicationController
  # The auto-save endpoint is hit with a flat JSON body via a raw fetch (see
  # app/frontend/lib/api.ts). Disable Rails' ParamsWrapper so it doesn't also
  # nest those fields under a phantom :presale_session key, which would otherwise
  # show up as an "Unpermitted parameters" warning on every save.
  wrap_parameters format: []

  before_action :set_session, only: %i[ setup profiling result present update debrief recap ]

  # Sessions area. Lists the current user's pre-sale sessions; the full archive
  # (search, delete) arrives in a later milestone.
  def index
    sessions = Current.user.presale_sessions.order(created_at: :desc)
    render inertia: "PresaleSessions/Index", props: {
      sessions: sessions.map { |session| session_summary(session) }
    }
  end

  def create
    session = Current.user.presale_sessions.create!
    redirect_to setup_presale_session_path(session)
  end

  # Step 1 of the internal flow: prospect data + industrial segment.
  def setup
    render inertia: "PresaleSessions/Setup", props: {
      session: session_detail(@session),
      segments: ContentConfig.segments
    }
  end

  # Step 2: the decision tree (5 questions, conditional skips), walked client-side.
  def profiling
    render inertia: "PresaleSessions/Profiling", props: {
      session: session_detail(@session),
      tree: ContentConfig.decision_tree
    }
  end

  # Step 3: the computed operational profile + the resolved criticality subset.
  def result
    segment = ContentConfig.segments.find { |s| s[:id] == @session.segment }
    render inertia: "PresaleSessions/Result", props: {
      session: session_detail(@session),
      segmentLabel: segment&.dig(:label),
      profileSteps: ContentConfig.decode_profile(@session.operational_profile),
      criticalities: ContentConfig.criticalities_for(
        segment: @session.segment,
        operational_profile: @session.operational_profile
      )
    }
  end

  # Prospect-facing context (first custom UI shown to the prospect): the criticality
  # hub + flow loop + closing page. Single Inertia page that switches views
  # client-side. Hands over the resolved criticality subset (or the full list of 13
  # as a predictable fallback when the segment x profile combo has no mapping) plus
  # the criticalities already discussed, so completed ones render as such.
  def present
    relevant = ContentConfig.criticalities_for(
      segment: @session.segment,
      operational_profile: @session.operational_profile
    )
    render inertia: "Present", props: {
      session: present_session(@session),
      criticalities: relevant.presence || ContentConfig.criticalities,
      prefiltered: relevant.any?,
      introSteps: ContentConfig.intro_steps,
      discussedCriticalities: @session.discussed_criticalities,
      stepsByCriticality: steps_by_criticality(@session),
      capturedQuestions: @session.captured_questions
    }
  end

  # End-of-call debrief (internal, template design system): summary of the session
  # + captured questions to edit, and a pre-composed recap body to send. Questions
  # are edited via the auto-save endpoint (update); sending happens via #recap.
  def debrief
    relevant = relevant_criticalities(@session)
    render inertia: "PresaleSessions/Debrief", props: {
      session: session_detail(@session),
      segmentLabel: ContentConfig.segments.find { |s| s[:id] == @session.segment }&.dig(:label),
      profileSteps: ContentConfig.decode_profile(@session.operational_profile),
      discussedCriticalities: discussed_criticality_labels(@session),
      capturedQuestions: enriched_questions(@session),
      defaultRecapBody: default_recap_body(@session, relevant)
    }
  end

  # Sends the recap email one-shot (synchronous, so failures surface and the status
  # only flips on success). The body is exactly what the operator reviewed/edited.
  def recap
    recipient = params[:recipient].to_s.strip
    body = params[:body].to_s

    errors = {}
    errors[:recipient] = "Inserisci un indirizzo email valido." unless recipient.match?(URI::MailTo::EMAIL_REGEXP)
    errors[:body] = "Il corpo del recap non può essere vuoto." if body.strip.empty?
    if errors.any?
      return redirect_to debrief_presale_session_path(@session), inertia: { errors: errors }
    end

    begin
      PresaleRecapMailer.recap(@session, to: recipient, body: body).deliver_now
    rescue StandardError => e
      Rails.logger.error("Recap delivery failed: #{e.class}: #{e.message}")
      return redirect_to debrief_presale_session_path(@session),
        inertia: { errors: { recipient: "Invio non riuscito, riprova." } }
    end

    @session.recap_sent!
    redirect_to debrief_presale_session_path(@session), notice: "Recap inviato a #{recipient}."
  end

  # Auto-save sink. Called via a raw fetch (not the Inertia router) as the
  # operator fills the session, so a bare head :ok is the correct response here —
  # no Inertia page or redirect.
  def update
    @session.update!(session_params)
    head :ok
  end

  private
    def set_session
      @session = Current.user.presale_sessions.find(params[:id])
    end

    def session_summary(session)
      {
        id: session.id,
        company_name: session.company_name,
        status: session.status,
        profiled: session.operational_profile.present?,
        created_at: session.created_at.iso8601
      }
    end

    def session_detail(session)
      session_summary(session).merge(
        contact_name: session.contact_name,
        segment: session.segment,
        operational_profile: session.operational_profile
      )
    end

    # Minimal slice for the prospect-facing surface: the hub + closing page need
    # the names, and the slide player needs the segment to build asset URLs.
    def present_session(session)
      {
        id: session.id,
        company_name: session.company_name,
        contact_name: session.contact_name,
        segment: session.segment
      }
    end

    # The resolved slide flow for every criticality, keyed by id, so the player
    # can look up the steps for whichever criticality the operator enters. Each
    # criticality's steps (and their phases) are discovered from the bitmaps and
    # resolved against this session's segment + operational profile (token/segment
    # override > shared default) — see ContentConfig.steps_for. Steps with no
    # bitmap simply have no phase URLs and the player shows a placeholder.
    def steps_by_criticality(session)
      ContentConfig.criticalities.to_h do |c|
        [
          c[:id],
          ContentConfig.steps_for(
            criticality_id: c[:id],
            segment: session.segment,
            operational_profile: session.operational_profile
          )
        ]
      end
    end

    # The criticalities shown in this session's hub: the resolved subset, or the
    # full list of 13 as the predictable fallback (same rule as #present).
    def relevant_criticalities(session)
      relevant = ContentConfig.criticalities_for(
        segment: session.segment,
        operational_profile: session.operational_profile
      )
      relevant.presence || ContentConfig.criticalities
    end

    # Labels of the criticalities actually discussed, in the order they were marked.
    def discussed_criticality_labels(session)
      by_id = ContentConfig.criticalities.index_by { |c| c[:id] }
      session.discussed_criticalities.filter_map { |id| by_id[id]&.dig(:label) }
    end

    # Captured questions with their criticality label resolved ("Generale" for the
    # ones captured from the hub, where criticality_id is null).
    def enriched_questions(session)
      by_id = ContentConfig.criticalities.index_by { |c| c[:id] }
      session.captured_questions.map do |q|
        label = q["criticality_id"] && by_id[q["criticality_id"]]&.dig(:label)
        q.merge("criticality_label" => label || "Generale")
      end
    end

    # Pre-composes the editable recap text: a greeting, the operative context, the
    # discussed criticalities, the captured questions, and the deep-dive video links
    # for every hub theme that has a resolved URL (placeholder content for now).
    def default_recap_body(session, relevant)
      contact = session.contact_name.presence
      company = session.company_name.presence || "la vostra azienda"
      lines = []
      lines << "Ciao#{contact ? " #{contact}" : ''},"
      lines << ""
      lines << "grazie per il tempo dedicato. Di seguito un riepilogo di quanto visto insieme per #{company}."

      discussed = discussed_criticality_labels(session)
      if discussed.any?
        lines << ""
        lines << "Temi affrontati:"
        discussed.each { |label| lines << "- #{label}" }
      end

      questions = session.captured_questions
      if questions.any?
        lines << ""
        lines << "Domande emerse:"
        questions.each { |q| lines << "- #{q['text']}" }
      end

      video_lines = relevant.filter_map do |c|
        url = ContentConfig.video_url_for(
          criticality_id: c[:id],
          segment: session.segment,
          operational_profile: session.operational_profile
        )
        "- #{c[:label]}: #{url}" if url
      end
      if video_lines.any?
        lines << ""
        lines << "Approfondimenti video:"
        lines.concat(video_lines)
      end

      lines << ""
      lines << "A presto,"
      lines << "il team Bravo Manufacturing"
      lines.join("\n")
    end

    def session_params
      # :id is the route param, not a model attribute — drop it before permitting
      # so it isn't logged as an unpermitted parameter on every auto-save.
      params.except(:id).permit(
        :company_name,
        :contact_name,
        :segment,
        :operational_profile,
        :status,
        discussed_criticalities: [],
        captured_questions: [ :id, :text, :criticality_id, :slide_id, :asked_at ]
      )
    end
end
