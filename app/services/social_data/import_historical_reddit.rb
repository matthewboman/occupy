require "csv"

module SocialData
  class ImportHistoricalReddit
    def initialize(path:)
      @path = Pathname.new(path)
    end

    def call
      raise "File not found: #{@path}" unless @path.exist?

      CSV.foreach(@path, headers: true) do |row|
        import_row(row)
      end
    end

    private

    def import_row(row)
      post = SocialPost.find_or_initialize_by(
        source:      "reddit",
        external_id: row.fetch("external_id")
      )

      post.update!(
        record_type:            row["record_type"].presence || "submission",
        submission_external_id: row["submission_external_id"],
        parent_external_id:     row["parent_external_id"],
        author:                 row["author"],
        body:                   row.fetch("body"),
        posted_at:              row.fetch("posted_at"),
        score:                  row["score"],
        url:                    row["url"]
      )
    end
  end
end