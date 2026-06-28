class AddHubspotFieldsToPresaleSessions < ActiveRecord::Migration[8.0]
  def change
    add_column :presale_sessions, :prospect_email, :string
    add_column :presale_sessions, :prospect_role, :string
    add_column :presale_sessions, :hubspot_contact_id, :string
    add_column :presale_sessions, :suggested_criticalities, :integer, array: true, null: false, default: []

    add_index :presale_sessions, :hubspot_contact_id
  end
end
