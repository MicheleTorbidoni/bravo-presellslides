class CreatePresaleSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :presale_sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :company_name
      t.string :contact_name
      t.string :segment
      t.string :operational_profile
      t.integer :discussed_criticalities, array: true, null: false, default: []
      t.string :status, null: false, default: "in_progress"

      t.timestamps
    end
  end
end
