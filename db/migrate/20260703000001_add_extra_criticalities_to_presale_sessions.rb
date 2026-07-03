class AddExtraCriticalitiesToPresaleSessions < ActiveRecord::Migration[8.0]
  def change
    # Criticalities added by the operator from *other* segments for this single
    # call. Each entry is { "id" => Integer, "segment" => String }: the origin
    # segment is remembered so the badge, the verticalized slides and the deep-dive
    # video resolve against it. Per-session only; cleared when the prospect's
    # segment changes. Empty by default.
    add_column :presale_sessions, :extra_criticalities, :jsonb, default: [], null: false
  end
end
