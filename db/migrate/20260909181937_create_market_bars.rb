class CreateMarketBars < ActiveRecord::Migration[8.1]
  def change
    create_table :market_bars do |t|
      t.references :security, null: false, foreign_key: true
      t.datetime :recorded_at, null: false
      t.decimal :open, precision: 18, scale: 6
      t.decimal :high, precision: 18, scale: 6
      t.decimal :low, precision: 18, scale: 6
      t.decimal :close, precision: 18, scale: 6
      t.bigint :volume

      t.timestamps
    end

    add_index :market_bars,
              [:security_id, :recorded_at],
              unique: true
  end
end