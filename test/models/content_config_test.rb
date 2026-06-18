require "test_helper"

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

  test "steps_for discovers the step/phase structure from the bitmaps" do
    steps = ContentConfig.steps_for(
      criticality_id: 1,
      segment: "meccanica",
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
      criticality_id: 1, segment: "meccanica", operational_profile: "ho-excel-bom-bom1"
    )
    with = ContentConfig.steps_for(
      criticality_id: 1, segment: "meccanica", operational_profile: "ho-excel-bom-bomN"
    )

    step2 = ->(steps) { steps.find { |s| s[:id] == "C01-step2" }[:phases].first }
    assert(step2.call(without).end_with?("C01-step2.png"))
    assert(step2.call(with).end_with?("C01-step2-bomN.png"))
  end

  test "steps_for returns [] for a criticality with no bitmaps" do
    assert_equal [], ContentConfig.steps_for(
      criticality_id: 99, segment: "meccanica", operational_profile: "ho-excel-bom-bom1"
    )
  end
end
