# Serves the prospect-facing slide media (bitmaps and minivideos) from
# content/assets/ at runtime.
#
# The assets live outside the web root and are picked by name. The slide player
# receives URLs already resolved by ContentConfig.steps_for, whose :dir is either
# "criticalities" (shared per-criticality media) or a segment id (per-segment
# override). This controller just serves the requested file. Kept behind the app's
# standard authentication (the slides are shown to the prospect through OBS within
# the logged-in operator's session).
#
# Steps with no media yet resolve to no URL, so the player renders a client-side
# placeholder; a stray request to a missing file returns 404 cleanly.
class PresentationAssetsController < ApplicationController
  ASSETS_DIR = Rails.root.join("content", "assets")
  CONTENT_TYPES = { ".png" => "image/png", ".mp4" => "video/mp4" }.freeze
  # URLs carry a ?v=<mtime> version (ContentConfig.asset_url), so a file can be
  # cached forever: a re-export under the same name gets a new URL. private, not
  # public — the assets sit behind authentication and must stay out of shared
  # caches; the browser's own cache is what makes the next call instant.
  CACHE_CONTROL = "private, max-age=31536000, immutable".freeze

  def show
    dir = params[:dir]
    return head(:not_found) unless valid_dir?(dir)

    # File.basename strips any directory component, defeating path traversal.
    filename = File.basename(params[:filename].to_s)
    path = ASSETS_DIR.join(dir, filename)
    content_type = CONTENT_TYPES[File.extname(filename)]
    return head(:not_found) unless content_type && File.file?(path)

    serve_file(path, content_type)
  end

  private
    def valid_dir?(dir)
      dir == ContentConfig::SHARED_DIR ||
        dir == ContentConfig::INTRO_DIR ||
        ContentConfig.segments.any? { |s| s[:id] == dir }
    end

    # Rails' send_file ignores the Range header (always a full 200), but video
    # playback needs byte ranges (Safari refuses to play an mp4 without them,
    # and they let the browser start/seek without the whole file). Rack::Files
    # implements them (206 + Content-Range, 416 when unsatisfiable, HEAD), so the
    # already-validated path is handed to it and its response is relayed as-is.
    def serve_file(path, content_type)
      status, headers, body = Rack::Files.new(nil).serving(request, path.to_s)
      # Rack::Files marks its own error responses (e.g. 416) "x-cascade: pass",
      # which would make the Rails router turn them into a 404.
      response.headers.merge!(headers.except("x-cascade"))
      # Our content type for the file itself (full or single-range); error and
      # multi-range responses keep the one Rack::Files set.
      response.headers["Content-Type"] = content_type if status == 200 || (status == 206 && headers.key?("content-range"))
      response.headers["Accept-Ranges"] = "bytes"
      # A strong validator: Chrome only stores partial (206) video responses in
      # its disk cache when it has one, and Rack::Files sends just Last-Modified
      # (which counts as weak without a Date header). Without it every new
      # page load would download the videos again; the bitmaps were unaffected.
      stat = File.stat(path)
      response.headers["ETag"] = %("#{stat.mtime.to_i.to_s(16)}-#{stat.size.to_s(16)}")
      response.headers["Cache-Control"] = CACHE_CONTROL
      self.status = status
      self.response_body = body
    end
end
