class AddSuspicionToMarketBars < ActiveRecord::Migration[8.1]
  def change
    add_column :market_bars,
               :suspicious,
               :boolean,
               null: false,
               default: false

    add_column :market_bars,
               :suspicion_reasons,
               :text,
               array: true,
               null: false,
               default: []

    add_index :market_bars,
              :suspicious
  end
end