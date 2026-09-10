class CreateSecurityMentionOutcomes < ActiveRecord::Migration[8.1]
  def change
    create_table :security_mention_outcomes do |t|
      t.references :security_mention, null: false, foreign_key: true
      t.date :market_date, null: false
      t.decimal :price_at_mention, precision: 18, scale: 6, null: false
      t.decimal :return_1d, precision: 12, scale: 6
      t.decimal :return_3d, precision: 12, scale: 6
      t.decimal :return_5d, precision: 12, scale: 6
      t.decimal :return_10d, precision: 12, scale: 6
      t.decimal :max_gain_10d, precision: 12, scale: 6
      t.decimal :max_drawdown_10d, precision: 12, scale: 6

      t.timestamps
    end

    add_index(
      :security_mention_outcomes,
      :security_mention_id,
      unique: true,
      name: "index_security_mention_outcomes_unique"
    )
  end
end