# Serves the prospect-facing slide bitmaps from content/assets/ at runtime.
#
# The assets live outside the web root (content/assets/<segment>/*.png and
# content/assets/common/*.png) and are picked by name: the slide player builds a
# URL like /presentation_assets/<segment>/<file>.png (segment variant) or
# /presentation_assets/common/<file>.png, and this controller resolves it to the
# matching file on disk. Kept behind the app's standard authentication (the slides
# are shown to the prospect through OBS within the logged-in operator's session).
#
# Many criticalities have no bitmaps yet, so a missing file returns 404 cleanly and
# the player renders a client-side placeholder instead of breaking the presentation.
class PresentationAssetsController < ApplicationController
  ASSETS_DIR = Rails.root.join("content", "assets")

  def show
    segment = params[:segment]
    return head(:not_found) unless valid_segment?(segment)

    # File.basename strips any directory component, defeating path traversal.
    filename = File.basename(params[:filename].to_s)
    path = ASSETS_DIR.join(segment, filename)
    return head(:not_found) unless File.file?(path)

    send_file path, type: "image/png", disposition: "inline"
  end

  private
    def valid_segment?(segment)
      segment == "common" ||
        ContentConfig.segments.any? { |s| s[:id] == segment }
    end
end
