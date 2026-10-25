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

  # The criticalities this session will present, as ids in no particular order.
  # Every criticality is selectable for every segment (the segment↔criticality
  # mapping in mappings.json only drives the "Tipica del segmento" hint in Setup).
  # nil selection means the operator never chose: default to the prospect's
  # HubSpot suggestions, else nothing. An explicit selection (including []) is
  # honoured, clamped to the known catalogue so stale ids can't leak through.
  def effective_selected_criticalities
    known = ContentConfig.criticalities.map { |c| c[:id] }
    (selected_criticalities.nil? ? suggested_criticalities : selected_criticalities) & known
  end

  # The full, ordered list of criticality ids (enabled and disabled) driving both
  # the Setup list and the presentation sequence: the saved order, clamped to the
  # catalogue, with any id not yet in it appended in canonical order.
  def effective_criticalities_order
    known = ContentConfig.criticalities.map { |c| c[:id] }
    saved = (criticalities_order || []) & known
    saved + (known - saved)
  end

  # The enabled criticalities ({ id:, label: }) in the operator's chosen order.
  def presented_criticalities
    ids = effective_selected_criticalities
    by_id = ContentConfig.criticalities.index_by { |c| c[:id] }
    effective_criticalities_order.select { |id| ids.include?(id) }.map { |id| by_id[id] }
  end

  # Whether an optional follow-up appointment with a salesperson has been set.
  def appointment?
    appointment_at.present?
  end

  # Whether Setup and Questionario A have gathered everything needed to move on
  # to the presentation: Setup.tsx's own gate (segment + at least one enabled
  # criticality) plus a completed operational profile. Drives the "Presentazione" row
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
