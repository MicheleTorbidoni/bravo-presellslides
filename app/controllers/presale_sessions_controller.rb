class PresaleSessionsController < ApplicationController
  before_action :set_session, only: %i[ setup profiling result update ]

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

    def session_params
      params.permit(
        :company_name,
        :contact_name,
        :segment,
        :operational_profile,
        :status,
        discussed_criticalities: []
      )
    end
end
