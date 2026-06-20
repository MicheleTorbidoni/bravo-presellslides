require "test_helper"
require "minitest/mock"

class ContentConfigTest < ActiveSupport::TestCase
  test "all config files load without raising" do
    assert_nothing_raised do
      ContentConfig.segments
      ContentConfig.decision_tree
      ContentConfig.criticalities
      ContentConfig.mappings
      ContentConfig.slides
    end
  end

  test "there are seven segments" do
    assert_equal 7, ContentConfig.segments.size
    assert(ContentConfig.segments.all? { |s| s[:id].present? && s[:label].present? })
  end

  test "there are thirteen criticalities with ids 1..13" do
    criticalities = ContentConfig.criticalities
    assert_equal 13, criticalities.size
    assert_equal (1..13).to_a, criticalities.map { |c| c[:id] }.sort
  end

  test "the decision tree has a valid start node" do
    tree = ContentConfig.decision_tree
    assert tree[:start].present?
    assert tree[:questions].key?(tree[:start].to_sym)
  end

  test "every mapping references a known segment and known criticalities" do
    segment_ids = ContentConfig.segments.map { |s| s[:id] }
    criticality_ids = ContentConfig.criticalities.map { |c| c[:id] }

    ContentConfig.mappings.each do |mapping|
      assert_includes segment_ids, mapping[:segment]
      assert mapping[:operationalProfile].present?
      mapping[:criticalities].each do |id|
        assert_includes criticality_ids, id
      end
    end
  end

  test "criticalities_for resolves a known segment x profile to its subset" do
    resolved = ContentConfig.criticalities_for(
      segment: "meccanica",
      operational_profile: "ho-excel-bom-bom1"
    )

    assert_equal [ 1, 2, 3, 4, 7, 8, 10 ], resolved.map { |c| c[:id] }
    assert(resolved.all? { |c| c[:label].present? })
  end

  test "the criticality subset is the same across all operational profiles of a segment" do
    subsets = ContentConfig.operational_profiles.map do |profile|
      ContentConfig.criticalities_for(
        segment: "meccanica",
        operational_profile: profile
      ).map { |c| c[:id] }
    end

    assert_equal 1, subsets.uniq.size, "expected identical copies across profiles for now"
    assert_equal [ 1, 2, 3, 4, 7, 8, 10 ], subsets.first
  end

  test "operational_profiles enumerates every decision-tree leaf path" do
    profiles = ContentConfig.operational_profiles

    assert_equal 18, profiles.size
    assert_equal profiles.size, profiles.uniq.size
    assert_includes profiles, "ho-excel-bom-bom1"
    assert_includes profiles, "mixed-noiot-mrp-nobom"
    # every enumerated profile decodes cleanly back through the tree
    assert(profiles.all? { |p| ContentConfig.decode_profile(p).any? })
  end

  test "every segment x operational profile combination has a non-empty mapping" do
    segment_ids = ContentConfig.segments.map { |s| s[:id] }
    profiles = ContentConfig.operational_profiles

    assert_equal segment_ids.size * profiles.size, ContentConfig.mappings.size

    segment_ids.each do |segment|
      profiles.each do |profile|
        resolved = ContentConfig.criticalities_for(
          segment: segment,
          operational_profile: profile
        )
        assert resolved.any?, "no criticalities for #{segment} x #{profile}"
      end
    end
  end

  test "criticalities_for returns [] for an unmapped combination (fallback)" do
    assert_equal [], ContentConfig.criticalities_for(
      segment: "meccanica",
      operational_profile: "does-not-exist"
    )
    assert_equal [], ContentConfig.criticalities_for(
      segment: "meccanica",
      operational_profile: nil
    )
  end

  test "decode_profile walks the tree into readable question/answer steps" do
    steps = ContentConfig.decode_profile("ho-excel-bom-bom1")

    assert_equal 4, steps.size
    assert_equal "La produzione è Human Only?", steps.first[:question]
    assert_equal "Sì", steps.first[:answer]
    assert_equal "Multilivello", ContentConfig.decode_profile("ho-excel-bom-bomN").last[:answer]
  end

  test "decode_profile handles a skipped-question path (d1=Sì skips d2)" do
    steps = ContentConfig.decode_profile("mixed-noiot-excel-nobom")

    # mixed -> d2 asked -> noiot -> excel -> nobom (d5 skipped)
    assert_equal %w[ d1 d2 d3 d4 ].size, steps.size
    assert_equal "No", steps.last[:answer]
  end

  test "decode_profile returns [] for a blank profile" do
    assert_equal [], ContentConfig.decode_profile(nil)
    assert_equal [], ContentConfig.decode_profile("")
  end

  # The shared `criticalities/` folder is the fallback baseline (segment: nil
  # exercises it directly, without coupling to per-segment art).
  test "steps_for discovers the step/phase structure from the shared bitmaps" do
    steps = ContentConfig.steps_for(
      criticality_id: 1,
      segment: nil,
      operational_profile: "ho-excel-bom-bom1"
    )

    assert_equal %w[ C01-step1 C01-step2 C01-step3 ], steps.map { |s| s[:id] }
    # step3 has two phases (C01-step3.f1 / .f2)
    assert_equal 2, steps.last[:phases].size
    assert(steps.first[:phases].first.include?("criticalities/C01-step1.png"))
    # title/body come from slides.json (carried over)
    assert_equal "Tempi disponibili da subito.", steps.first[:title]
  end

  test "steps_for applies a token override when the profile contains the token" do
    without = ContentConfig.steps_for(
      criticality_id: 1, segment: nil, operational_profile: "ho-excel-bom-bom1"
    )
    with = ContentConfig.steps_for(
      criticality_id: 1, segment: nil, operational_profile: "ho-excel-bom-bomN"
    )

    step2 = ->(steps) { steps.find { |s| s[:id] == "C01-step2" }[:phases].first }
    assert(step2.call(without).end_with?("C01-step2.png"))
    assert(step2.call(with).end_with?("C01-step2-bomN.png"))
  end

  test "intro_steps resolves the shared intro flow with texts from intro.json" do
    steps = ContentConfig.intro_steps

    assert_equal %w[ Intro-step1 Intro-step2 Intro-step3 ], steps.map { |s| s[:id] }
    assert(steps.first[:phases].first.end_with?("/presentation_assets/intro/Intro-step1.png"))
    # titles/body come from intro.json (text-per-step)
    assert_equal "Benvenuto.", steps.first[:title]
  end

  test "parse_asset_name accepts the Intro code without breaking criticalities" do
    intro = ContentConfig.send(:parse_asset_name, "Intro-step2.png")
    assert_equal "Intro", intro[:code]
    assert_equal 2, intro[:step]
    assert_nil intro[:token]

    crit = ContentConfig.send(:parse_asset_name, "C01-step3.f2.png")
    assert_equal "C01", crit[:code]
    assert_equal 3, crit[:step]
    assert_equal 2, crit[:phase]
  end

  test "video_url_for reads videos.json: a configured url resolves, an unknown criticality is nil" do
    # Content-agnostic (URLs in videos.json are placeholders that will be replaced):
    # criticality 1 is configured, so it resolves; criticality 999 does not exist.
    assert ContentConfig.video_url_for(
      criticality_id: 1, segment: "meccanica", operational_profile: "ho-excel-bom-bom1"
    ).present?
    assert_nil ContentConfig.video_url_for(
      criticality_id: 999, segment: nil, operational_profile: nil
    )
  end

  test "video_url_for precedence: segment+token > token > segment > base" do
    fixture = [ {
      id: 50,
      url: "BASE",
      tokens: { bomN: "SHARED-TOKEN" },
      segments: { meccanica: { url: "SEG", tokens: { bomN: "SEG-TOKEN" } } }
    } ]
    ContentConfig.stub :videos, fixture do
      # segment+token override is the most specific
      assert_equal "SEG-TOKEN", ContentConfig.video_url_for(
        criticality_id: 50, segment: "meccanica", operational_profile: "ho-excel-bom-bomN"
      )
      # a segment with no entry falls through to the shared token override
      assert_equal "SHARED-TOKEN", ContentConfig.video_url_for(
        criticality_id: 50, segment: "elettronica", operational_profile: "ho-excel-bom-bomN"
      )
      # no matching token → the segment default beats the base
      assert_equal "SEG", ContentConfig.video_url_for(
        criticality_id: 50, segment: "meccanica", operational_profile: "ho-excel-bom-bom1"
      )
      # no segment, no matching token → the shared base
      assert_equal "BASE", ContentConfig.video_url_for(
        criticality_id: 50, segment: nil, operational_profile: "ho-excel-bom-bom1"
      )
    end
  end

  test "steps_for returns [] for a criticality with no bitmaps" do
    assert_equal [], ContentConfig.steps_for(
      criticality_id: 90, segment: "meccanica", operational_profile: "ho-excel-bom-bom1"
    )
  end

  # The tests below use fictitious criticalities (C97/C98/C99) so they create and
  # remove their own fixtures without ever touching the real per-segment art. Each
  # test owns a distinct code so they don't collide on disk when the suite runs in
  # parallel processes.

  test "steps_for takes the step/phase structure from the segment folder, shared as fallback" do
    with_assets(
      "criticalities/C97-step1.png", "criticalities/C97-step2.png",
      "meccanica/C97-step1.png", "meccanica/C97-step2.png", "meccanica/C97-step3.png"
    ) do
      meccanica = ContentConfig.steps_for(
        criticality_id: 97, segment: "meccanica", operational_profile: "ho-excel-bom-bom1"
      )
      elettronica = ContentConfig.steps_for(
        criticality_id: 97, segment: "elettronica", operational_profile: "ho-excel-bom-bom1"
      )

      # meccanica authors its own flow (3 steps)
      assert_equal %w[ C97-step1 C97-step2 C97-step3 ], meccanica.map { |s| s[:id] }
      # a segment with no C97 art falls back to the shared structure (2 steps)
      assert_equal %w[ C97-step1 C97-step2 ], elettronica.map { |s| s[:id] }
    end
  end

  test "steps_for resolves the segment image and falls back to shared for other segments" do
    with_assets("criticalities/C98-step1.png", "meccanica/C98-step1.png") do
      assert(seg_step1_url(98, segment: "meccanica").end_with?("meccanica/C98-step1.png"))
      assert(seg_step1_url(98, segment: "elettronica").end_with?("criticalities/C98-step1.png"))
    end
  end

  test "steps_for precedence: segment+token > shared token > segment default > shared default" do
    # segment+token beats the shared token
    with_assets(
      "criticalities/C99-step1.png", "criticalities/C99-step1-bomN.png",
      "meccanica/C99-step1.png", "meccanica/C99-step1-bomN.png"
    ) do
      assert(seg_step1_url(99, segment: "meccanica", profile: "ho-excel-bom-bomN")
        .end_with?("meccanica/C99-step1-bomN.png"))
    end

    # without a segment token file, the shared token beats the segment default;
    # with no matching token, the segment default beats the shared default
    with_assets(
      "criticalities/C99-step1.png", "criticalities/C99-step1-bomN.png",
      "meccanica/C99-step1.png"
    ) do
      assert(seg_step1_url(99, segment: "meccanica", profile: "ho-excel-bom-bomN")
        .end_with?("criticalities/C99-step1-bomN.png"))
      assert(seg_step1_url(99, segment: "meccanica", profile: "ho-excel-bom-bom1")
        .end_with?("meccanica/C99-step1.png"))
    end
  end

  private
    def seg_step1_url(criticality_id, segment:, profile: "ho-excel-bom-bom1")
      steps = ContentConfig.steps_for(
        criticality_id: criticality_id, segment: segment, operational_profile: profile
      )
      step_id = format("C%02d-step1", criticality_id)
      steps.find { |s| s[:id] == step_id }&.dig(:phases)&.first
    end

    # Creates tiny PNG fixtures under content/assets/ for the duration of the
    # block, then removes them. Lets the file-driven resolver be exercised
    # without committing art to the repo. Use only filenames (e.g. C99-*) that
    # do not collide with real bitmaps, since the fixtures are deleted on exit.
    def with_assets(*relative_paths)
      paths = relative_paths.map { |rp| Rails.root.join("content", "assets", rp) }
      paths.each do |path|
        FileUtils.mkdir_p(path.dirname)
        File.binwrite(path, "")
      end
      yield
    ensure
      paths&.each { |path| FileUtils.rm_f(path) }
    end
end
