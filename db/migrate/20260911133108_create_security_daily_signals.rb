class CreateSecurityDailySignals < ActiveRecord::Migration[8.1]
  def change
    create_table :security_daily_signals do |t|
      t.references :security, null: false, foreign_key: true
      t.date :date, null: false
      t.integer :mention_count, null: false, default: 0
      t.integer :submission_count, null: false, default: 0
      t.integer :comment_count, null: false, default: 0
      t.integer :unique_author_count, null: false, default: 0
      t.integer :total_score, null: false, default: 0
      t.decimal :average_score, precision: 12, scale: 4

      t.timestamps
    end

    add_index(
      :security_daily_signals,
      [:security_id, :date],
      unique: true
    )
  end
end