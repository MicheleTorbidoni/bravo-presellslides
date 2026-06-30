class AddCriticalitiesOrderAndShowHubToPresaleSessions < ActiveRecord::Migration[8.0]
  def change
    # Ordered, full list of criticality ids for the session's segment (enabled and
    # disabled alike), so the operator's drag order survives toggling. nil means
    # "never reordered" — fall back to the segment's default order.
    add_column :presale_sessions, :criticalities_order, :integer, array: true, default: nil
    # Whether the criticality hub is shown after the intro. When false, the enabled
    # criticalities play in sequence and the hub is only reached at the end.
    add_column :presale_sessions, :show_hub, :boolean, default: true, null: false
  end
end
