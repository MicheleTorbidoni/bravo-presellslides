class AddPublicTokenToPresaleSessions < ActiveRecord::Migration[8.0]
  def change
    add_column :presale_sessions, :public_token, :string
    add_index :presale_sessions, :public_token, unique: true
  end
end
