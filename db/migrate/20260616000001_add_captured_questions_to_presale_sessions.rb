class AddCapturedQuestionsToPresaleSessions < ActiveRecord::Migration[8.0]
  def change
    add_column :presale_sessions, :captured_questions, :jsonb, default: [], null: false
  end
end
