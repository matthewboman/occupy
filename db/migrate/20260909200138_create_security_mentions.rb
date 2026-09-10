class CreateSecurityMentions < ActiveRecord::Migration[8.1]
  def change
    create_table :security_mentions do |t|
      t.references :social_post,
                   null: false,
                   foreign_key: true

      t.references :security,
                   null: false,
                   foreign_key: true

      t.timestamps
    end

    add_index :security_mentions,
              [:social_post_id, :security_id],
              unique: true
  end
end