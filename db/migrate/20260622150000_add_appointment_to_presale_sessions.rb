class AddAppointmentToPresaleSessions < ActiveRecord::Migration[8.0]
  def change
    add_column :presale_sessions, :appointment_at, :datetime
    add_column :presale_sessions, :appointment_sales_name, :string
    add_column :presale_sessions, :appointment_location, :string
  end
end
