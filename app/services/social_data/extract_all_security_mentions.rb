module SocialData
  class ExtractAllSecurityMentions
    def call
      SocialPost.find_each do |social_post|
        ExtractSecurityMentions.new(
          social_post: social_post
        ).call
      end
    end
  end
end