require "test_helper"

class VideoEmbedTest < ActiveSupport::TestCase
  test "converts a YouTube watch URL into a nocookie embed" do
    assert_equal "https://www.youtube-nocookie.com/embed/abc123",
      VideoEmbed.url("https://www.youtube.com/watch?v=abc123")
  end

  test "converts a youtu.be short URL" do
    assert_equal "https://www.youtube-nocookie.com/embed/abc123",
      VideoEmbed.url("https://youtu.be/abc123")
  end

  test "normalizes an already-embed YouTube URL" do
    assert_equal "https://www.youtube-nocookie.com/embed/abc123",
      VideoEmbed.url("https://www.youtube.com/embed/abc123")
  end

  test "converts a Vimeo URL into a player embed" do
    assert_equal "https://player.vimeo.com/video/76979871",
      VideoEmbed.url("https://vimeo.com/76979871")
  end

  test "returns nil for unrecognized or blank input" do
    assert_nil VideoEmbed.url("https://example.com/video/123")
    assert_nil VideoEmbed.url("not a url at all")
    assert_nil VideoEmbed.url(nil)
    assert_nil VideoEmbed.url("")
  end
end
