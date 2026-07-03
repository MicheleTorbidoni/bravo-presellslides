class AddQualificationAnswersToPresaleSessions < ActiveRecord::Migration[8.0]
  def change
    add_column :presale_sessions, :qualification_answers, :jsonb, null: false, default: {}
  end
end
