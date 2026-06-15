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

    assert_equal [ 1, 3, 4, 7, 12 ], resolved.map { |c| c[:id] }
    assert(resolved.all? { |c| c[:label].present? })
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
end
