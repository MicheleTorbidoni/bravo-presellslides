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
  SHARED_DIR = "criticalities" # content/assets/criticalities/ holds the shared slide media
  INTRO_DIR = "intro" # content/assets/intro/ holds the shared intro media
  # Slide media by extension: a phase is either a bitmap or a minivideo (M19).
  MEDIA_KINDS = { "png" => "image", "mp4" => "video" }.freeze
  # Suffixes tried at each link of the resolution chain, most specific first:
  # for the same logical name a spoken video beats a muted one beats a bitmap.
  MEDIA_SUFFIXES = %w[ .audio.mp4 .mp4 .png ].freeze

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

    # The sales-qualification questionnaire, split across two screens by group:
    # phase 1 (Questionario A, before Setup) holds the decision-tree groups plus
    # context groups; phase 2 (Questionario B, after the presentation) holds the
    # remaining company/headcount group. Each group is an ordered list of items
    # that are either a reference to a decision-tree question ({ ref: }) or an
    # inline extra field ({ field:, label:, type:, options?, visible_if? }). See
    # content/config/questionnaire.json. Pass no `phase` to get every group
    # (used by questionnaire_field_keys, which permits fields from both phases).
    def questionnaire(phase: nil)
      raw = load_config("questionnaire")
      return raw if phase.nil?

      { groups: raw.fetch(:groups).select { |g| g[:phase] == phase } }
    end

    # The inline field keys of the questionnaire, split by whether the value is an
    # array (multi_select) or a scalar. Used by the controller to permit
    # qualification_answers to exactly the known keys (no arbitrary mass-assignment,
    # no permit!). Decision-tree refs are skipped — they are not stored here.
    def questionnaire_field_keys
      multi = []
      scalar = []
      questionnaire.fetch(:groups, []).each do |group|
        group.fetch(:items, []).each do |item|
          field = item[:field]
          next if field.nil?

          (item[:type] == "multi_select" ? multi : scalar) << field.to_sym
        end
      end
      { multi_select: multi, scalar: scalar }
    end

    # Resolves the deep-dive video URL for a criticality in the session's operative
    # context, most specific first — mirroring resolve_phase. videos.json shape
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
    # phase structure is discovered from the shared media in
    # content/assets/criticalities/ (named C<NN>-step<Y>[-<token>][.f<Z>][.audio].<png|mp4>),
    # and each phase is resolved against the operative context with the
    # chain: token override > segment override > shared default.
    #
    # Returns an ordered array of steps:
    #   [ { id: "C01-step2", title:, body:,
    #       phases: [ { url: "/presentation_assets/.../C01-step2.png?v=…", kind: "image", audio: false }, … ] }, … ]
    # kind is "image" or "video"; audio is true only for a spoken .audio.mp4.
    # Title/body come from slides.json (text-per-step); a step/phase with no file
    # resolves to no phase and the player shows a placeholder.
    def steps_for(criticality_id:, segment:, operational_profile:)
      code = format("C%02d", criticality_id)
      tokens = operational_profile.to_s.split("-")
      listing = asset_listing

      structure = step_structure(code, segment, listing) # { step_index => [phase_or_nil, …] }
      texts = step_texts(criticality_id)

      structure.keys.sort.map do |y|
        phases = structure[y].map do |phase|
          resolve_phase(code: code, step: y, phase: phase, segment: segment, tokens: tokens, listing: listing)
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
    # set (content/assets/intro/Intro-step<Y>[.f<Z>][.audio].<png|mp4>) — not
    # verticalized per segment and with no token variants — so resolution is a
    # plain lookup in the intro folder. Structure (number of steps/phases) is
    # file-driven; titles/body come from intro.json (text-per-step), empty when
    # the file is absent.
    def intro_steps
      listing = asset_listing
      structure = structure_in_dir(INTRO_DIR, "Intro", listing) # { step_index => [phase_or_nil, …] }
      texts = intro_texts

      structure.keys.sort.map do |y|
        phases = structure[y].map do |phase|
          media_in(INTRO_DIR, "Intro-step#{y}#{phase ? ".f#{phase}" : ''}", listing)
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

    # Resolves the criticality subset for a segment (industrial category) as the
    # union of every mapping for that segment in mappings.json, deduplicated and
    # returned in canonical order (the order of criticalities.json). The subset is
    # segment-driven only: the operational_profile no longer selects *which*
    # criticalities appear (it only varies the content *inside* each flow — see
    # steps_for / video_url_for). Returns the matching criticality hashes
    # ({ id:, label: }), or [] for a blank/unknown segment. Since Fase 8 this no
    # longer restricts which criticalities a session may present (every one is
    # selectable for every segment): it only drives Setup's "Tipica del segmento"
    # hint.
    def criticalities_for_segment(segment:)
      return [] if segment.blank?

      ids = mappings.select { |m| m[:segment] == segment }
                    .flat_map { |m| m[:criticalities] }
                    .to_set
      criticalities.select { |c| ids.include?(c[:id]) }
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
      # media (no token suffix). Returns { step_index => [phases] }, where
      # phases is [nil] for a single-media step or [1, 2, …] for a multi-phase
      # step. The structure is segment-driven: the segment folder is the source
      # of truth for the criticalities it covers (each segment authors its own
      # flow); the shared folder is the fallback for criticalities the segment
      # does not provide. Token variants do not change the structure — they only
      # swap which file a given (step, phase) resolves to.
      def step_structure(code, segment, listing)
        segment_structure = structure_in_dir(segment, code, listing) if segment.present?
        return segment_structure if segment_structure.present?

        structure_in_dir(SHARED_DIR, code, listing)
      end

      # Builds { step_index => [phases] } from the default (no-token) media of
      # one criticality in a single directory — bitmaps and videos count alike.
      # Empty when the directory is absent or has no matching files.
      def structure_in_dir(dir, code, listing)
        by_step = Hash.new { |h, k| h[k] = [] }
        listing[dir].each do |file|
          parsed = parse_asset_name(file)
          next unless parsed && parsed[:code] == code && parsed[:token].nil?

          by_step[parsed[:step]] << parsed[:phase]
        end
        by_step.transform_values { |phases| phases.uniq.sort_by { |p| p || 0 } }
      end

      # Parses "C01-step3[-token][.f1][.audio].mp4" → { code:, step:, token:,
      # phase:, kind:, audio: }. Returns nil for names that don't match the
      # convention (including any other extension, e.g. a source .mov, and an
      # .audio suffix on a bitmap). A hyphenated "-audio" is read as a token.
      def parse_asset_name(file)
        ext = File.extname(file).delete_prefix(".")
        kind = MEDIA_KINDS[ext]
        return nil unless kind

        base = File.basename(file, ".#{ext}")
        audio = base.end_with?(".audio")
        return nil if audio && kind != "video"

        base = base.delete_suffix(".audio")
        rest, phase = base.split(".f", 2)
        return nil if phase && phase !~ /\A\d+\z/

        parts = rest.split("-")
        return nil unless parts.size >= 2 && parts[0] =~ /\A(?:C\d{2}|Intro)\z/ && parts[1] =~ /\Astep\d+\z/

        {
          code: parts[0],
          step: parts[1].delete_prefix("step").to_i,
          token: (parts[2..].join("-") if parts.size > 2),
          phase: phase&.to_i,
          kind: kind,
          audio: audio
        }
      end

      # Resolves one (step, phase) to a served phase, most specific first:
      # segment+token > token (shared) > segment default > shared default.
      # At each link the media suffixes are tried in priority order
      # (.audio.mp4 > .mp4 > .png), so the chain still beats the extension.
      # Returns nil if none.
      def resolve_phase(code:, step:, phase:, segment:, tokens:, listing:)
        suffix = phase ? ".f#{phase}" : ""

        # Deepest decision wins: try the profile's tokens from the leaf back.
        # For each token, a segment-verticalized variant beats the shared one.
        tokens.reverse_each do |token|
          base = "#{code}-step#{step}-#{token}#{suffix}"
          found = (media_in(segment, base, listing) if segment.present?) || media_in(SHARED_DIR, base, listing)
          return found if found
        end

        base = "#{code}-step#{step}#{suffix}"
        (media_in(segment, base, listing) if segment.present?) || media_in(SHARED_DIR, base, listing)
      end

      # The phase for a logical name (no extension) in one directory, trying the
      # media suffixes in priority order; nil when no file matches.
      def media_in(dir, base, listing)
        MEDIA_SUFFIXES.each do |media_suffix|
          name = "#{base}#{media_suffix}"
          next unless listing[dir].include?(name)

          return {
            url: asset_url(dir, name),
            kind: MEDIA_KINDS.fetch(File.extname(name).delete_prefix(".")),
            audio: media_suffix.start_with?(".audio")
          }
        end
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

      # A lazy per-call index of the asset directories: each folder is read once
      # (one Dir.children) and every probe of the resolution chain is then an
      # in-memory lookup instead of a File.file? syscall. Built fresh by each
      # steps_for/intro_steps call, so nothing goes stale across requests.
      def asset_listing
        Hash.new do |h, dir|
          path = ASSETS_DIR.join(dir.to_s)
          h[dir] = Dir.exist?(path) ? Dir.children(path).to_set : Set.new
        end
      end

      # The served URL, versioned by the file's mtime: assets are cached as
      # immutable by the browser (see PresentationAssetsController), so a file
      # re-exported under the same name gets a new URL and is fetched again.
      def asset_url(dir, filename)
        version = File.mtime(ASSETS_DIR.join(dir, filename)).to_i
        "/presentation_assets/#{dir}/#{filename}?v=#{version}"
      end
  end
end
