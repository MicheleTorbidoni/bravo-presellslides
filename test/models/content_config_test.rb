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
end
