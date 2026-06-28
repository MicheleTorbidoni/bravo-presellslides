module Hubspot
  # Applies a batch of HubSpot contact webhook events to the matching PresaleSession.
  # For now we only care about the prospect's criticality selection: a
  # `contact.propertyChange` on CRITICALITY_PROPERTY whose value is the `;`-separated
  # list of chosen criticality ids. The session is found via the hubspot_contact_id
  # captured at booking time (M11).
  #
  # Robust by design — it ignores what it doesn't recognise: events of other types or
  # properties, contacts with no matching session, and ids that aren't real
  # criticalities. Writing is idempotent: each propertyChange carries the property's
  # full current value, so we replace the stored set rather than accumulate.
  class ApplyContactEvents
    def self.call(events)
      Array(events).each { |event| new(event).apply }
    end

    def initialize(event)
      @event = event.to_h.with_indifferent_access
    end

    def apply
      return unless @event[:subscriptionType] == "contact.propertyChange"
      return unless @event[:propertyName] == Hubspot::CRITICALITY_PROPERTY

      session = session_for(@event[:objectId])
      return unless session

      session.update!(suggested_criticalities: parsed_ids(@event[:propertyValue]))
    end

    private
      # Most recent session for the contact: a contact could re-book, and the latest
      # call is the one being prepared.
      def session_for(object_id)
        contact_id = object_id.to_s
        return if contact_id.blank?

        PresaleSession.where(hubspot_contact_id: contact_id).order(:created_at).last
      end

      # ";"-separated ids → unique, sorted integers, keeping only real criticalities.
      def parsed_ids(value)
        valid = ContentConfig.criticalities.map { |c| c[:id] }.to_set
        value.to_s.split(";").map { |token| token.strip.to_i }.select { |id| valid.include?(id) }.uniq.sort
      end
  end
end
