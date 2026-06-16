# Reads the static content configuration that drives the pre-sale sessions.
#
# These files live under content/config/ and are edited by hand (no admin UI for
# the MVP). Nothing here is persisted to the database — see PresaleSession for the
# durable per-call record.
#
# In production the parsed files are memoized for the life of the process. In a
# local/dev environment they are re-read on every call so editing a JSON file is
# picked up without restarting the server.
module ContentConfig
  CONFIG_DIR = Rails.root.join("content", "config")

  class << self
    def segments
      load_config("segments").fetch(:segments)
    end

    def decision_tree
      load_config("decision-tree")
    end

    def criticalities
      load_config("criticalities").fetch(:criticalities)
    end

    def mappings
      load_config("mappings").fetch(:mappings)
    end

    def slides
      load_config("slides").fetch(:criticalities)
    end

    # Resolves the relevant criticalities for a (segment, operational_profile)
    # combination by looking it up in mappings.json. Returns the matching
    # criticality hashes ({ id:, label: }) in the order declared in the mapping,
    # or [] when there is no mapping for the combination (predictable fallback —
    # the operator will then choose freely in the hub).
    def criticalities_for(segment:, operational_profile:)
      mapping = mappings.find do |m|
        m[:segment] == segment && m[:operationalProfile] == operational_profile
      end
      return [] unless mapping

      by_id = criticalities.index_by { |c| c[:id] }
      mapping[:criticalities].filter_map { |id| by_id[id] }
    end

    # Turns a composite operational_profile key (e.g. "ho-excel-bom-bom1") into a
    # human-readable path by walking the decision tree from the start node,
    # consuming one token per question. Returns [{ question:, answer: }] — used to
    # show the profiling outcome on the result screen. Unknown tokens stop the walk.
    def decode_profile(operational_profile)
      return [] if operational_profile.blank?

      tree = decision_tree
      tokens = operational_profile.split("-")
      question_id = tree[:start]
      steps = []

      tokens.each do |token|
        question = tree.dig(:questions, question_id.to_sym)
        break unless question

        answer = question[:answers].find { |a| a[:code] == token }
        break unless answer

        steps << { question: question[:text], answer: answer[:label] }
        question_id = answer[:next]
        break unless question_id
      end

      steps
    end

    # Enumerates every complete operational profile (leaf path) of the decision
    # tree as a "-"-joined token string, in depth-first order. These are exactly
    # the operational_profile values the profiling UI can produce (it walks the
    # tree until an answer has no :next — see Profiling.tsx). Used to build the
    # full set of (segment x profile) mappings and to assert their coverage.
    def operational_profiles
      tree = decision_tree
      profiles = []

      walk = lambda do |question_id, tokens|
        question = tree.dig(:questions, question_id.to_sym)
        return if question.nil?

        question[:answers].each do |answer|
          path = tokens + [ answer[:code] ]
          if answer[:next]
            walk.call(answer[:next], path)
          else
            profiles << path.join("-")
          end
        end
      end

      walk.call(tree[:start], [])
      profiles
    end

    # Clears the in-memory cache. Mainly useful in tests.
    def reload!
      @cache = {}
    end

    private
      def load_config(name)
        return read_config(name) unless Rails.env.production?

        @cache ||= {}
        @cache[name] ||= read_config(name)
      end

      def read_config(name)
        path = CONFIG_DIR.join("#{name}.json")
        JSON.parse(path.read, symbolize_names: true)
      end
  end
end
