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

  # Assigns a public token the first time it's needed — in practice, the first
  # time the debrief page is viewed (see PresaleSessionsController#debrief) —
  # then leaves it untouched so the prospect's link stays stable. The token is
  # what makes the otherwise-public recap page impossible to guess.
  def ensure_public_token!
    return public_token if public_token.present?

    update!(public_token: SecureRandom.urlsafe_base64(24))
    public_token
  end

  # Whether an optional follow-up appointment with a salesperson has been set.
  def appointment?
    appointment_at.present?
  end

  # Whether Setup has gathered everything needed to move on to the
  # presentation — the same gate Setup.tsx's own advance() checks before
  # letting the full pass proceed into Present. Drives the "Presentazione" row
  # action's enabled/disabled state on the sessions list.
  def setup_complete?
    segment.present? && operational_profile.present? && selected_criticalities.present?
  end

  # Whether the presentation itself is done: the call has been closed (see
  # PresaleSessions::Qualification's finish(), which flips status here once
  # Questionario B is submitted) or the recap has since been sent. Drives the
  # "Riepilogo" row action's enabled/disabled state on the sessions list.
  def presentation_complete?
    closed? || recap_sent?
  end
end
