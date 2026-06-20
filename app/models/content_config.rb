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
  ASSETS_DIR = Rails.root.join("content", "assets")
  SHARED_DIR = "criticalities" # content/assets/criticalities/ holds the shared bitmaps
  INTRO_DIR = "intro" # content/assets/intro/ holds the shared intro bitmaps

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

    def videos
      load_config("videos").fetch(:videos)
    end

    # Resolves the deep-dive video URL for a criticality in the session's operative
    # context, most specific first — mirroring resolve_phase_url. videos.json shape
    # per criticality: { url:, tokens: { <token>: url }, segments: { <segment>: {
    # url:, tokens: { <token>: url } } } }. For each profile token (deepest decision
    # first) try the segment+token override, then the shared token; then the segment
    # default, then the shared default. Returns nil when nothing matches (the recap
    # then simply omits the link).
    def video_url_for(criticality_id:, segment:, operational_profile:)
      entry = videos.find { |v| v[:id] == criticality_id }
      return nil unless entry

      seg = segment.present? ? entry.dig(:segments, segment.to_sym) : nil
      tokens = operational_profile.to_s.split("-")

      tokens.reverse_each do |token|
        if seg
          seg_token = seg.dig(:tokens, token.to_sym)
          return seg_token if seg_token.present?
        end
        shared_token = entry.dig(:tokens, token.to_sym)
        return shared_token if shared_token.present?
      end

      return seg[:url] if seg && seg[:url].present?
      entry[:url].presence
    end

    # Builds the resolved slide flow for a criticality, file-driven: the step and
    # phase structure is discovered from the shared bitmaps in
    # content/assets/criticalities/ (named C<NN>-step<Y>[-<token>][.f<Z>].png),
    # and each phase image is resolved against the operative context with the
    # chain: token override > segment override > shared default.
    #
    # Returns an ordered array of steps:
    #   [ { id: "C01-step2", title:, body:, phases: ["/presentation_assets/.../C01-step2.png", …] }, … ]
    # Title/body come from slides.json (text-per-step); a step/phase with no file
    # resolves to no URL and the player shows a placeholder.
    def steps_for(criticality_id:, segment:, operational_profile:)
      code = format("C%02d", criticality_id)
      tokens = operational_profile.to_s.split("-")

      structure = step_structure(code, segment) # { step_index => [phase_or_nil, …] }
      texts = step_texts(criticality_id)

      structure.keys.sort.map do |y|
        phases = structure[y].map do |phase|
          resolve_phase_url(code: code, step: y, phase: phase, segment: segment, tokens: tokens)
        end.compact
        text = texts[y - 1] || {}
        {
          id: "#{code}-step#{y}",
          title: text[:title],
          body: text[:body],
          phases: phases
        }
      end
    end

    # Builds the resolved intro flow shown before the hub. Same step shape as
    # steps_for, so the player renders it unchanged. The intro is a single shared
    # set (content/assets/intro/Intro-step<Y>[.f<Z>].png) — not verticalized per
    # segment and with no token variants — so resolution is a plain lookup in the
    # intro folder. Structure (number of steps/phases) is file-driven; titles/body
    # come from intro.json (text-per-step), empty when the file is absent.
    def intro_steps
      structure = structure_in_dir(INTRO_DIR, "Intro") # { step_index => [phase_or_nil, …] }
      texts = intro_texts

      structure.keys.sort.map do |y|
        phases = structure[y].map do |phase|
          name = "Intro-step#{y}#{phase ? ".f#{phase}" : ''}.png"
          asset_url(INTRO_DIR, name) if asset_exists?(INTRO_DIR, name)
        end.compact
        text = texts[y - 1] || {}
        {
          id: "Intro-step#{y}",
          title: text[:title],
          body: text[:body],
          phases: phases
        }
      end
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

      # Discovers the step/phase structure of a criticality from the default
      # bitmaps (no token suffix). Returns { step_index => [phases] }, where
      # phases is [nil] for a single-image step or [1, 2, …] for a multi-phase
      # step. The structure is segment-driven: the segment folder is the source
      # of truth for the criticalities it covers (each segment authors its own
      # flow); the shared folder is the fallback for criticalities the segment
      # does not provide. Token variants do not change the structure — they only
      # swap which file a given (step, phase) resolves to.
      def step_structure(code, segment)
        segment_structure = structure_in_dir(segment, code) if segment.present?
        return segment_structure if segment_structure.present?

        structure_in_dir(SHARED_DIR, code)
      end

      # Builds { step_index => [phases] } from the default (no-token) bitmaps of
      # one criticality in a single directory. Empty when the directory is
      # absent or has no matching files.
      def structure_in_dir(dir, code)
        path = ASSETS_DIR.join(dir)
        return {} unless Dir.exist?(path)

        by_step = Hash.new { |h, k| h[k] = [] }
        Dir.children(path).each do |file|
          parsed = parse_asset_name(file)
          next unless parsed && parsed[:code] == code && parsed[:token].nil?

          by_step[parsed[:step]] << parsed[:phase]
        end
        by_step.transform_values { |phases| phases.uniq.sort_by { |p| p || 0 } }
      end

      # Parses "C01-step3.f1[-token].png" → { code:, step:, token:, phase: }.
      # Returns nil for names that don't match the convention.
      def parse_asset_name(file)
        base = File.basename(file, ".png")
        rest, phase = base.split(".f", 2)
        return nil if phase && phase !~ /\A\d+\z/

        parts = rest.split("-")
        return nil unless parts.size >= 2 && parts[0] =~ /\A(?:C\d{2}|Intro)\z/ && parts[1] =~ /\Astep\d+\z/

        {
          code: parts[0],
          step: parts[1].delete_prefix("step").to_i,
          token: (parts[2..].join("-") if parts.size > 2),
          phase: phase&.to_i
        }
      end

      # Resolves one (step, phase) to a served URL, most specific first:
      # segment+token > token (shared) > segment default > shared default.
      # Returns nil if none.
      def resolve_phase_url(code:, step:, phase:, segment:, tokens:)
        suffix = phase ? ".f#{phase}" : ""

        # Deepest decision wins: try the profile's tokens from the leaf back.
        # For each token, a segment-verticalized variant beats the shared one.
        tokens.reverse_each do |token|
          name = "#{code}-step#{step}-#{token}#{suffix}.png"
          return asset_url(segment, name) if segment.present? && asset_exists?(segment, name)
          return asset_url(SHARED_DIR, name) if asset_exists?(SHARED_DIR, name)
        end

        default = "#{code}-step#{step}#{suffix}.png"
        return asset_url(segment, default) if segment.present? && asset_exists?(segment, default)
        return asset_url(SHARED_DIR, default) if asset_exists?(SHARED_DIR, default)

        nil
      end

      def step_texts(criticality_id)
        crit = slides.find { |c| c[:id] == criticality_id }
        crit ? Array(crit[:steps]) : []
      end

      # Per-step intro titles/bodies from intro.json; [] when the file is absent.
      def intro_texts
        return [] unless CONFIG_DIR.join("intro.json").file?

        Array(load_config("intro")[:steps])
      end

      def asset_exists?(dir, filename)
        File.file?(ASSETS_DIR.join(dir, filename))
      end

      def asset_url(dir, filename)
        "/presentation_assets/#{dir}/#{filename}"
      end
  end
end
