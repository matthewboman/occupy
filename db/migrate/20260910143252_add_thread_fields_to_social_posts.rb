class AddThreadFieldsToSocialPosts < ActiveRecord::Migration[8.1]
  def change
    add_column :social_posts, :record_type, :string, null: false, default: "submission"
    add_column :social_posts, :submission_external_id, :string
    add_column :social_posts, :parent_external_id, :string

    add_index :social_posts, :record_type
    add_index :social_posts, :submission_external_id
    add_index :social_posts, :parent_external_id
  end
end