# The durable record of a single pre-sale call. It is created when the operator
# starts a session and updated (auto-save) as the call progresses, so nothing is
# lost if the browser is closed. The live slide-viewing state stays client-side
# and is intentionally not persisted here.
class PresaleSession < ApplicationRecord
  belongs_to :user

  enum :status, {
    in_progress: "in_progress",
    closed: "closed",
    recap_sent: "recap_sent"
  }, default: "in_progress"

  # Intentionally lax: an empty session must be creatable at the start of a call,
  # then filled in as the operator profiles the prospect.

  # Assigns a public token the first time it's needed (on the first recap send),
  # then leaves it untouched so the prospect's link stays stable. The token is what
  # makes the otherwise-public recap page impossible to guess.
  def ensure_public_token!
    return public_token if public_token.present?

    update!(public_token: SecureRandom.urlsafe_base64(24))
    public_token
  end
end
