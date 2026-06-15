class PresaleSessionsController < ApplicationController
  # Minimal sessions area for milestone 1: list the current user's pre-sale
  # sessions and start a new (empty) one. Search, detail and delete arrive with
  # the full archive in a later milestone.
  def index
    sessions = Current.user.presale_sessions.order(created_at: :desc)
    render inertia: "PresaleSessions/Index", props: {
      sessions: sessions.map { |session| session_summary(session) }
    }
  end

  def create
    Current.user.presale_sessions.create!
    redirect_to presale_sessions_path, notice: "Nuova sessione creata."
  end

  # Auto-save sink. Called via a raw fetch (not the Inertia router) as the
  # operator fills the session in later milestones, so a bare head :ok is the
  # correct response here — no Inertia page or redirect.
  def update
    session = Current.user.presale_sessions.find(params[:id])
    session.update!(session_params)
    head :ok
  end

  private
    def session_summary(session)
      {
        id: session.id,
        company_name: session.company_name,
        status: session.status,
        created_at: session.created_at.iso8601
      }
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
