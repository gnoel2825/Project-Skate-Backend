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

ActiveRecord::Schema[8.1].define(version: 2026_03_16_022725) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "attendances", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "lesson_plan_occurrence_id", null: false
    t.text "note"
    t.string "status", default: "present", null: false
    t.integer "student_id", null: false
    t.datetime "updated_at", null: false
    t.index ["lesson_plan_occurrence_id", "student_id"], name: "index_attendances_on_lesson_plan_occurrence_id_and_student_id", unique: true
    t.index ["lesson_plan_occurrence_id"], name: "index_attendances_on_lesson_plan_occurrence_id"
    t.index ["student_id"], name: "index_attendances_on_student_id"
  end

  create_table "lesson_plan_occurrences", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.time "ends_at"
    t.integer "lesson_plan_id", null: false
    t.string "location"
    t.integer "roster_id"
    t.time "starts_at"
    t.date "taught_on", null: false
    t.datetime "updated_at", null: false
    t.index ["lesson_plan_id", "taught_on"], name: "index_lesson_plan_occurrences_on_lesson_plan_id_and_taught_on"
    t.index ["lesson_plan_id"], name: "index_lesson_plan_occurrences_on_lesson_plan_id"
    t.index ["roster_id"], name: "index_lesson_plan_occurrences_on_roster_id"
    t.index ["taught_on"], name: "index_lesson_plan_occurrences_on_taught_on"
  end

  create_table "lesson_plan_skills", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "lesson_plan_id", null: false
    t.text "notes"
    t.integer "position"
    t.string "role"
    t.integer "skill_id", null: false
    t.datetime "updated_at", null: false
    t.index ["lesson_plan_id", "position"], name: "index_lesson_plan_skills_on_lesson_plan_id_and_position"
    t.index ["lesson_plan_id", "skill_id", "role"], name: "idx_on_lesson_plan_id_skill_id_role_b7eff0251f", unique: true
    t.index ["lesson_plan_id"], name: "index_lesson_plan_skills_on_lesson_plan_id"
    t.index ["skill_id"], name: "index_lesson_plan_skills_on_skill_id"
  end

  create_table "lesson_plans", force: :cascade do |t|
    t.text "cooldown_notes"
    t.datetime "created_at", null: false
    t.text "description"
    t.text "main_notes"
    t.integer "teacher_id", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.text "warmup_notes"
    t.index ["teacher_id"], name: "index_lesson_plans_on_teacher_id"
  end

  create_table "roster_meetings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "ends_at"
    t.string "location"
    t.integer "roster_id", null: false
    t.datetime "starts_at"
    t.date "taught_on"
    t.datetime "updated_at", null: false
    t.index ["roster_id"], name: "index_roster_meetings_on_roster_id"
  end

  create_table "roster_schedules", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.time "ends_at"
    t.string "location"
    t.integer "roster_id", null: false
    t.time "starts_at"
    t.datetime "updated_at", null: false
    t.integer "weekday"
    t.index ["roster_id"], name: "index_roster_schedules_on_roster_id"
  end

  create_table "roster_students", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "roster_id", null: false
    t.integer "student_id", null: false
    t.datetime "updated_at", null: false
    t.index ["roster_id"], name: "index_roster_students_on_roster_id"
    t.index ["student_id"], name: "index_roster_students_on_student_id"
  end

  create_table "roster_teachers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "roster_id", null: false
    t.integer "teacher_id", null: false
    t.datetime "updated_at", null: false
    t.index ["roster_id", "teacher_id"], name: "index_roster_teachers_on_roster_id_and_teacher_id", unique: true
    t.index ["roster_id"], name: "index_roster_teachers_on_roster_id"
    t.index ["teacher_id"], name: "index_roster_teachers_on_teacher_id"
  end

  create_table "rosters", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "teacher_id", null: false
    t.datetime "updated_at", null: false
    t.index ["teacher_id"], name: "index_rosters_on_teacher_id"
  end

  create_table "skills", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.boolean "is_active", default: true, null: false
    t.integer "level"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_skills_on_name", unique: true
  end

  create_table "students", force: :cascade do |t|
    t.date "birthday"
    t.datetime "created_at", null: false
    t.string "email"
    t.string "first_name"
    t.string "last_name"
    t.text "notes"
    t.integer "teacher_id", null: false
    t.datetime "updated_at", null: false
    t.index ["teacher_id"], name: "index_students_on_teacher_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "auth_token"
    t.datetime "created_at", null: false
    t.string "email"
    t.string "first_name"
    t.string "last_name"
    t.string "password_digest"
    t.string "role", default: "none", null: false
    t.datetime "updated_at", null: false
    t.index ["auth_token"], name: "index_users_on_auth_token", unique: true
    t.index ["role"], name: "index_users_on_role"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "attendances", "lesson_plan_occurrences"
  add_foreign_key "attendances", "students"
  add_foreign_key "lesson_plan_occurrences", "lesson_plans"
  add_foreign_key "lesson_plan_occurrences", "rosters"
  add_foreign_key "lesson_plan_skills", "lesson_plans"
  add_foreign_key "lesson_plan_skills", "skills"
  add_foreign_key "lesson_plans", "users", column: "teacher_id"
  add_foreign_key "roster_meetings", "rosters"
  add_foreign_key "roster_schedules", "rosters"
  add_foreign_key "roster_students", "rosters"
  add_foreign_key "roster_students", "students"
  add_foreign_key "roster_teachers", "rosters"
  add_foreign_key "roster_teachers", "users", column: "teacher_id"
  add_foreign_key "rosters", "users", column: "teacher_id"
  add_foreign_key "students", "users", column: "teacher_id"
end
