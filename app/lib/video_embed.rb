# Converts a deep-dive video link (as stored in content/config/videos.json) into
# an embeddable player URL for the prospect's public recap page. YouTube links
# (watch?v=, youtu.be/, /embed/) become privacy-enhanced youtube-nocookie embeds;
# Vimeo links become player.vimeo.com embeds. Anything unrecognized returns nil,
# so the page falls back to a plain external link.
module VideoEmbed
  module_function

  YOUTUBE_HOSTS = %w[youtube.com www.youtube.com m.youtube.com youtu.be youtube-nocookie.com www.youtube-nocookie.com].freeze
  VIMEO_HOSTS = %w[vimeo.com www.vimeo.com player.vimeo.com].freeze

  def url(raw)
    raw = raw.to_s.strip
    return nil if raw.empty?

    uri = begin
      URI.parse(raw)
    rescue URI::InvalidURIError
      return nil
    end
    return nil unless uri.host

    host = uri.host.downcase
    if YOUTUBE_HOSTS.include?(host)
      id = youtube_id(uri)
      id && "https://www.youtube-nocookie.com/embed/#{id}"
    elsif VIMEO_HOSTS.include?(host)
      id = vimeo_id(uri)
      id && "https://player.vimeo.com/video/#{id}"
    end
  end

  def youtube_id(uri)
    if uri.host.downcase.end_with?("youtu.be")
      uri.path.delete_prefix("/").presence
    elsif uri.path.start_with?("/embed/")
      uri.path.delete_prefix("/embed/").presence
    else
      URI.decode_www_form(uri.query.to_s).to_h["v"].presence
    end
  end

  def vimeo_id(uri)
    # The numeric (or placeholder) id is the last non-empty path segment.
    uri.path.split("/").reject(&:empty?).last.presence
  end
end
