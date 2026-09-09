class CreateSocialPosts < ActiveRecord::Migration[8.1]
  def change
    create_table :social_posts do |t|
      t.references :security, null: false, foreign_key: true

      t.string :source, null: false
      t.string :external_id, null: false
      t.string :author
      t.text :body, null: false
      t.datetime :posted_at, null: false
      t.integer :score
      t.string :url

      t.timestamps
    end

    add_index :social_posts,
              [:source, :external_id],
              unique: true

    add_index :social_posts, :posted_at
    add_index :social_posts, [:security_id, :posted_at]
  end
end