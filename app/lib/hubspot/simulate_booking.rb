require "net/http"

module Hubspot
  # The in-app HubSpot simulator (M13). Generates placeholder booking data, signs it
  # exactly as HubSpot would (Hubspot::WebhookSignature) and makes a *real* signed POST
  # to the two webhook endpoints — first the appointment (creating the session), then a
  # random criticality selection (annotating it as suggested). Nothing is written to the
  # database directly: the round-trip goes through the same signature-verified endpoints
  # a real HubSpot would hit, so wiring the real account later changes configuration, not
  # this code.
  #
  # The payload builders and the random selection are split out so they can be unit-tested
  # and fed through the endpoints without opening a socket; only #post_signed touches the
  # network.
  class SimulateBooking
    # Small Italian-flavoured pools for believable placeholder data. No external deps.
    FIRST_NAMES = %w[ Marco Giulia Luca Francesca Andrea Chiara Matteo Sara Davide Elena ].freeze
    LAST_NAMES  = %w[ Rossi Bianchi Ferrari Esposito Romano Colombo Ricci Marino Greco Conti ].freeze
    COMPANY_CORE = %w[ Acme Meccanica Nuova Tecno Industrie Officine Gamma Delta Sigma Prima ].freeze
    COMPANY_SUFFIX = %w[ Srl Spa & C. Group Industriale ].freeze
    ROLES = [
      "Responsabile produzione", "Direttore operativo", "Titolare",
      "Responsabile qualità", "Plant manager", "Responsabile pianificazione"
    ].freeze
    LOCATIONS = [ "Videocall", "Sede cliente", "Sede Bravo Manufacturing" ].freeze
    SALES_NAMES = [ "Loredana Mosca", "Giorgio Bravi" ].freeze

    Result = Struct.new(:session_id, :data, :suggested_ids, keyword_init: true)

    def self.call(base_url:)
      new(base_url:).call
    end

    def initialize(base_url:)
      @base_url = base_url.to_s.chomp("/")
    end

    def call
      data = generate_data
      session_id = create_session(data)
      suggested_ids = random_suggested(segment: data[:industry])
      apply_selection(contact_id: data[:contactId], criticality_ids: suggested_ids)
      Result.new(session_id: session_id, data: data, suggested_ids: suggested_ids)
    end

    # Placeholder booking — the flat-JSON shape Hubspot::CreateSessionFromBooking reads.
    # `industry` is always one of the app's known segments so the suggested subset is
    # never empty.
    def generate_data
      first = FIRST_NAMES.sample
      last = LAST_NAMES.sample
      company = "#{COMPANY_CORE.sample} #{COMPANY_SUFFIX.sample}"
      {
        contactId: SecureRandom.hex(8),
        firstname: first,
        lastname: last,
        company: company,
        email: "#{first}.#{last}@#{company_slug(company)}.it".downcase,
        jobtitle: ROLES.sample,
        industry: ContentConfig.segments.sample[:id],
        appointmentAt: rand(1..14).days.from_now.change(hour: [ 9, 10, 11, 14, 15, 16 ].sample, min: 0).iso8601,
        salesName: SALES_NAMES.sample,
        location: LOCATIONS.sample
      }
    end

    # A small, non-empty subset of the segment's criticality ids (the prospect's pick).
    # Real prospects flag one or two pain points, not the whole list — so cap the pick at
    # two even when the segment subset is larger.
    def random_suggested(segment:)
      ids = ContentConfig.criticalities_for_segment(segment: segment).map { |c| c[:id] }
      return [] if ids.empty?

      ids.sample([ rand(1..2), ids.size ].min).sort
    end

    def appointment_body(data)
      data.to_json
    end

    def selection_body(contact_id:, criticality_ids:)
      [ {
        objectId: contact_id,
        subscriptionType: "contact.propertyChange",
        propertyName: Hubspot::CRITICALITY_PROPERTY,
        propertyValue: criticality_ids.join(";")
      } ].to_json
    end

    private
      def create_session(data)
        response = post_signed(path: "/integrations/hubspot/appointments", body: appointment_body(data))
        unless response.code.to_i == 201
          raise "Appointment webhook failed (#{response.code}): #{response.body}"
        end

        JSON.parse(response.body).fetch("id")
      end

      def apply_selection(contact_id:, criticality_ids:)
        return if criticality_ids.empty?

        body = selection_body(contact_id: contact_id, criticality_ids: criticality_ids)
        response = post_signed(path: "/integrations/hubspot/contact_events", body: body)
        unless response.code.to_i == 200
          raise "Selection webhook failed (#{response.code}): #{response.body}"
        end
      end

      # The only networked step: a real signed POST to one of our own endpoints. The
      # signed URL is the full original URL the endpoint will reconstruct, so the HMAC
      # matches regardless of host/port.
      def post_signed(path:, body:)
        url = "#{@base_url}#{path}"
        uri = URI(url)
        timestamp = (Time.now.to_f * 1000).to_i.to_s
        signature = Hubspot::WebhookSignature.sign(method: "POST", url: url, body: body, timestamp: timestamp)

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = (uri.scheme == "https")
        request = Net::HTTP::Post.new(uri)
        request["Content-Type"] = "application/json"
        request["X-HubSpot-Request-Timestamp"] = timestamp
        request["X-HubSpot-Signature-v3"] = signature
        request.body = body
        http.request(request)
      end

      def company_slug(company)
        company.parameterize(separator: "")
      end
  end
end
