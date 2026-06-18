# Serves the prospect-facing slide bitmaps from content/assets/ at runtime.
#
# The assets live outside the web root and are picked by name. The slide player
# receives URLs already resolved by ContentConfig.steps_for, whose :dir is either
# "criticalities" (shared per-criticality bitmaps) or a segment id (per-segment
# override). This controller just serves the requested file. Kept behind the app's
# standard authentication (the slides are shown to the prospect through OBS within
# the logged-in operator's session).
#
# Steps with no bitmap yet resolve to no URL, so the player renders a client-side
# placeholder; a stray request to a missing file returns 404 cleanly.
class PresentationAssetsController < ApplicationController
  ASSETS_DIR = Rails.root.join("content", "assets")

  def show
    dir = params[:dir]
    return head(:not_found) unless valid_dir?(dir)

    # File.basename strips any directory component, defeating path traversal.
    filename = File.basename(params[:filename].to_s)
    path = ASSETS_DIR.join(dir, filename)
    return head(:not_found) unless File.file?(path)

    send_file path, type: "image/png", disposition: "inline"
  end

  private
    def valid_dir?(dir)
      dir == "criticalities" ||
        ContentConfig.segments.any? { |s| s[:id] == dir }
    end
end
