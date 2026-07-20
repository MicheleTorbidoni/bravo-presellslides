module Admin
  # Internal HubSpot simulator (Fase 3, M13). One click generates placeholder booking
  # data and drives the *real* signed webhook round-trip (Hubspot::SimulateBooking),
  # then shows the session it created — proof that the same endpoints a real HubSpot
  # would hit work end-to-end.
  class HubspotSimulatorController < Admin::BaseController
    def show
      render inertia: "admin/hubspot-simulator", props: {
        createdSession: created_session_summary
      }
    end

    def simulate
      result = ::Hubspot::SimulateBooking.call(base_url: request.base_url)
      reassign_to_current_admin(result.session_id)
      redirect_to admin_hubspot_simulator_path,
        notice: "Prenotazione simulata: sessione ##{result.session_id} creata.",
        flash: { created_session_id: result.session_id }
    rescue ::Hubspot::CreateSessionFromBooking::NoOperatorError
      redirect_to admin_hubspot_simulator_path,
        inertia: { errors: { base: "Nessun operatore a cui assegnare la sessione. Crea prima un utente." } }
    rescue StandardError => e
      Rails.logger.error("HubSpot simulation failed: #{e.class}: #{e.message}")
      redirect_to admin_hubspot_simulator_path,
        inertia: { errors: { base: "Simulazione non riuscita: #{e.message}" } }
    end

    private
      # CreateSessionFromBooking assigns the real webhook's inbound sessions to the
      # configured operator (env var, else User.first) — correct for production, where
      # there's a single real operator. The simulator has no such config in dev/test, so
      # that fallback can land on a different user than the admin running the simulation,
      # making the session invisible on their own /presale_sessions list. Reassign it to
      # whoever clicked "simulate" so the round-trip is actually visible to them.
      def reassign_to_current_admin(session_id)
        session = PresaleSession.find(session_id)
        session.update!(user: Current.user) unless session.user_id == Current.user.id
      end

      # The session created by the most recent simulation (carried across the redirect
      # in the flash), shaped for the result card. nil on a fresh page load.
      def created_session_summary
        id = flash[:created_session_id]
        return nil if id.blank?

        session = PresaleSession.find_by(id: id)
        return nil unless session

        {
          id: session.id,
          company_name: session.company_name,
          contact_name: session.contact_name,
          prospect_email: session.prospect_email,
          prospect_role: session.prospect_role,
          segment_label: ContentConfig.segments.find { |s| s[:id] == session.segment }&.dig(:label),
          suggested: suggested_labels(session),
          hub_url: present_presale_session_path(session),
          setup_url: setup_presale_session_path(session)
        }
      end

      def suggested_labels(session)
        by_id = ContentConfig.criticalities.index_by { |c| c[:id] }
        session.suggested_criticalities.filter_map { |cid| by_id[cid]&.dig(:label) }
      end
  end
end
