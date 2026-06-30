class AddSetupControlsToPresaleSessions < ActiveRecord::Migration[8.0]
  def change
    # Operator's chosen subset of criticalities to discuss. Intentionally nullable
    # with NO default: nil means "never chosen" (fall back to the computed default
    # — suggested ∩ segment, else all of the segment), while an explicit array
    # (including []) means the operator made a deliberate choice. This is why it
    # differs from suggested_/discussed_criticalities, which are null: false [].
    add_column :presale_sessions, :selected_criticalities, :integer, array: true

    # Whether the prospect-facing intro plays at the start of the presentation.
    add_column :presale_sessions, :show_intro, :boolean, null: false, default: true
  end
end
