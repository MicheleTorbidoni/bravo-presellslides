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
