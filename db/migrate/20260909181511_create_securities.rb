class CreateSecurities < ActiveRecord::Migration[8.1]
  def change
    create_table :securities do |t|
      t.string :symbol, null: false
      t.string :name
      t.string :security_type
      t.string :exchange
      t.boolean :is_active, null: false, default: true

      t.timestamps
    end

    add_index :securities, :symbol, unique: true
    add_index :securities, :is_active
  end
end