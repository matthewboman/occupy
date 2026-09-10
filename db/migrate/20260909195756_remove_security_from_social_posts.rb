class RemoveSecurityFromSocialPosts < ActiveRecord::Migration[8.1]
  def change
    remove_reference :social_posts,
                     :security,
                     foreign_key: true
  end
end