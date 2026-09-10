# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_09_10_153322) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "market_bars", force: :cascade do |t|
    t.decimal "close", precision: 18, scale: 6
    t.datetime "created_at", null: false
    t.decimal "high", precision: 18, scale: 6
    t.decimal "low", precision: 18, scale: 6
    t.decimal "open", precision: 18, scale: 6
    t.datetime "recorded_at", null: false
    t.bigint "security_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "volume"
    t.index ["security_id", "recorded_at"], name: "index_market_bars_on_security_id_and_recorded_at", unique: true
    t.index ["security_id"], name: "index_market_bars_on_security_id"
  end

  create_table "securities", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "exchange"
    t.boolean "is_active", default: true, null: false
    t.string "name"
    t.string "security_type"
    t.string "symbol", null: false
    t.datetime "updated_at", null: false
    t.index ["is_active"], name: "index_securities_on_is_active"
    t.index ["symbol"], name: "index_securities_on_symbol", unique: true
  end

  create_table "security_mentions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "security_id", null: false
    t.bigint "social_post_id", null: false
    t.datetime "updated_at", null: false
    t.index ["security_id"], name: "index_security_mentions_on_security_id"
    t.index ["social_post_id", "security_id"], name: "index_security_mentions_on_social_post_id_and_security_id", unique: true
    t.index ["social_post_id"], name: "index_security_mentions_on_social_post_id"
  end

  create_table "social_posts", force: :cascade do |t|
    t.string "author"
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.string "external_id", null: false
    t.string "parent_external_id"
    t.datetime "posted_at", null: false
    t.string "record_type", default: "submission", null: false
    t.integer "score"
    t.string "source", null: false
    t.string "submission_external_id"
    t.string "subreddit"
    t.datetime "updated_at", null: false
    t.string "url"
    t.index ["parent_external_id"], name: "index_social_posts_on_parent_external_id"
    t.index ["posted_at"], name: "index_social_posts_on_posted_at"
    t.index ["record_type"], name: "index_social_posts_on_record_type"
    t.index ["source", "external_id"], name: "index_social_posts_on_source_and_external_id", unique: true
    t.index ["submission_external_id"], name: "index_social_posts_on_submission_external_id"
    t.index ["subreddit"], name: "index_social_posts_on_subreddit"
  end

  add_foreign_key "market_bars", "securities"
  add_foreign_key "security_mentions", "securities"
  add_foreign_key "security_mentions", "social_posts"
end
