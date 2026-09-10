require "csv"

module SocialData
  class ImportHistoricalReddit
    BATCH_SIZE = 1_000

    def initialize(path:)
      @path = Pathname.new(path)
    end

    def call
      raise "File not found: #{@path}" unless @path.exist?

      rows = []

      CSV.foreach(@path, headers: true) do |row|
        rows << build_attributes(row)

        next unless rows.size >= BATCH_SIZE

        import_batch(rows)
        rows.clear
      end

      import_batch(rows) if rows.any?
    end

    private

    def build_attributes(row)
      now = Time.current

      {
        source:                 "reddit",
        subreddit:              row["subreddit"],
        external_id:            row.fetch("external_id"),
        record_type:            row["record_type"].presence || "submission",
        submission_external_id: row["submission_external_id"],
        parent_external_id:     row["parent_external_id"],
        author:                 row["author"],
        body:                   row.fetch("body"),
        posted_at:              row.fetch("posted_at"),
        score:                  row["score"],
        url:                    row["url"],
        created_at:             now,
        updated_at:             now
      }
    end

    def import_batch(rows)
      SocialPost.upsert_all(
        rows,
        unique_by: [:source, :external_id],
        update_only: [
          :subreddit,
          :record_type,
          :submission_external_id,
          :parent_external_id,
          :author,
          :body,
          :posted_at,
          :score,
          :url
        ]
      )

      external_ids = rows.pluck(:external_id)

      SocialPost.where(
        source: "reddit",
        external_id: external_ids
      ).find_each do |social_post|
        ExtractSecurityMentions.new(
          social_post: social_post
        ).call
      end
    end
  end
end