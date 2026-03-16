# db/seeds.rb

puts "🌱 Starting seeds..."

# =========================
# Users
# =========================
users = [
  { email: "test@example.com", first_name: "Test", last_name: "Admin", role: "admin" },
  { email: "debug@example.com", first_name: "Debug", last_name: "User", role: "teacher" },
  { email: "x@example.com", first_name: "X", last_name: "User", role: "teacher" },
  { email: "coach@example.com", first_name: "Coach", last_name: "Teacher", role: "teacher" }
]

users.each do |attrs|
  user = User.find_or_initialize_by(email: attrs[:email])
  user.assign_attributes(
    first_name: attrs[:first_name],
    last_name: attrs[:last_name],
    password: "password",
    password_confirmation: "password",
    role: attrs[:role]
  )
  user.save!
end

puts "✅ Seeded #{User.count} users"

admin_user = User.find_by!(email: "test@example.com")
teacher = User.find_by!(email: "coach@example.com")

# =========================
# Skills
# =========================
skills = [
  { level: 1, name: "Sit on ice and stand up" },
  { level: 1, name: "March forward across the ice" },
  { level: 1, name: "Forward two-foot glide" },
  { level: 1, name: "Dip" },
  { level: 1, name: "Forward swizzles (6–8 in a row)" },
  { level: 1, name: "Backward wiggles (6–8 in a row)" },
  { level: 1, name: "Beginning snowplow stop (two feet or one foot)" },
  { level: 1, name: "Bonus: Two-foot hop in place" },

  { level: 2, name: "Scooter pushes (R and L)" },
  { level: 2, name: "Forward one-foot glides (R and L)" },
  { level: 2, name: "Backward two-foot glide (length of skater’s height)" },
  { level: 2, name: "Rocking Horse (forward + backward swizzle, repeat twice)" },
  { level: 2, name: "Backward swizzles (6–8 in a row)" },
  { level: 2, name: "Two-foot turns forward to backward (CW and CCW)" },
  { level: 2, name: "Moving snowplow stop" },
  { level: 2, name: "Bonus: Curves" },

  { level: 3, name: "Beginning forward stroking (correct blade use)" },
  { level: 3, name: "Forward half swizzle pumps on a circle (CW & CCW)" },
  { level: 3, name: "Moving forward to backward two-foot turns on a circle" },
  { level: 3, name: "Beginning backward one-foot glides (balance focus)" },
  { level: 3, name: "Backward snowplow stop (R and L)" },
  { level: 3, name: "Forward slalom" },
  { level: 3, name: "Bonus: Forward pivots (CW and CCW)" },

  { level: 4, name: "Forward outside edge on a circle (R and L)" },
  { level: 4, name: "Forward inside edge on a circle (R and L)" },
  { level: 4, name: "Forward crossovers (CW and CCW)" },
  { level: 4, name: "Backward half swizzle pumps on a circle (CW & CCW)" },
  { level: 4, name: "Backward one-foot glides (R and L)" },
  { level: 4, name: "Beginning two-foot spin (up to 2 revs)" },
  { level: 4, name: "Bonus: Forward lunges (both legs)" },

  { level: 5, name: "Backward outside edge on a circle (R and L)" },
  { level: 5, name: "Backward inside edge on a circle (R and L)" },
  { level: 5, name: "Backward crossovers (CW and CCW)" },
  { level: 5, name: "Forward outside three-turn (R and L)" },
  { level: 5, name: "Advanced two-foot spin (4–6 revs)" },
  { level: 5, name: "Hockey stop (both directions)" },
  { level: 5, name: "Bonus: Side toe hop (R and L)" },

  { level: 6, name: "Forward inside three-turn (R and L)" },
  { level: 6, name: "Moving backward to forward two-foot turn on a circle" },
  { level: 6, name: "Backward stroking" },
  { level: 6, name: "Beginning one-foot spin (2–4 revs)" },
  { level: 6, name: "T-stops (R and L)" },
  { level: 6, name: "Bunny hop" },
  { level: 6, name: "Forward spiral on a straight line (R or L)" },
  { level: 6, name: "Bonus: Shoot the duck (R or L)" }
]

skills.each do |skill|
  record = Skill.find_or_initialize_by(name: skill[:name])
  record.level = skill[:level]
  record.is_active = true if record.respond_to?(:is_active=)
  record.save!
end

puts "✅ Seeded #{Skill.count} skills"

# =========================
# Students
# =========================
puts "🌱 Seeding students..."

FIRST_NAMES = %w[
  Ava Olivia Emma Charlotte Amelia Sophia Isabella Mia Evelyn Harper
  Liam Noah Oliver Elijah James William Benjamin Lucas Henry Alexander
  Ella Grace Chloe Lily Zoey Riley Aria Scarlett Hannah Audrey
]

LAST_NAMES = %w[
  Smith Johnson Williams Brown Jones Garcia Miller Davis Rodriguez Martinez
  Hernandez Lopez Gonzalez Wilson Anderson Thomas Taylor Moore Jackson Martin
  Lee Perez Thompson White Harris Sanchez Clark Ramirez Lewis Robinson
]

100.times do |i|
  first = FIRST_NAMES.sample
  last = LAST_NAMES.sample
  email = "#{first.downcase}.#{last.downcase}#{i}@student.com"

  student = Student.find_or_initialize_by(email: email)
  student.assign_attributes(
    teacher: teacher,
    first_name: first,
    last_name: last,
    birthday: Date.today - rand(6..16).years,
    notes: [ "Focus on edges", "Working on spins", "Needs confidence", nil ].sample
  )
  student.save!
end

puts "✅ Seeded #{teacher.students.count} students for #{teacher.email}"
# =========================
# Lesson Plans + Occurrences
# =========================
puts "🌱 Seeding lesson plans + occurrences..."

SKILL_POOL = Skill.order(:level, :name).to_a
raise "No skills found. Seed skills first." if SKILL_POOL.empty?

PLAN_TITLES = [
  "Edges & Balance Focus",
  "Basic Crossovers Session",
  "Stops & Control",
  "Spins Foundations",
  "Backward Skating Builder",
  "Confidence + Flow Lesson",
  "Skills Check-in",
  "Test Prep: Basic Level",
  "Warmup + Technique Day",
  "Power + Stroking"
]

PLAN_DESCRIPTIONS = [
  "Warm-up, then targeted drills. Finish with a quick review + cool down.",
  "Technique-first session. Keep reps clean and controlled.",
  "Focus on posture, knee bend, and smooth pressure on the blade.",
  "Build confidence with short sets and lots of feedback.",
  "Work skills in both directions and end with a fun combo."
]

LOCATIONS = [
  "Main Rink",
  "Practice Rink",
  "Studio Ice",
  "North Arena",
  "South Arena"
]

def rand_date_within(days_forward: 30)
  Date.today + rand(0..days_forward)
end

def rand_time_range
  start_hour = rand(15..20)
  start_min = [ 0, 15, 30, 45 ].sample
  duration = [ 30, 45, 60 ].sample

  start_str = format("%02d:%02d", start_hour, start_min)
  end_minutes = (start_hour * 60 + start_min + duration)
  end_hour = end_minutes / 60
  end_min = end_minutes % 60
  end_str = format("%02d:%02d", end_hour, end_min)

  [ start_str, end_str ]
end

30.times do |i|
  title = "#{PLAN_TITLES.sample} ##{i + 1}"

  lp = LessonPlan.find_or_initialize_by(
    teacher: teacher,
    title: title
  )

  lp.description = PLAN_DESCRIPTIONS.sample
  lp.save!

  selected_skills = SKILL_POOL.sample(rand(4..10))

  lp.lesson_plan_skills.destroy_all

  selected_skills.each_with_index do |skill, idx|
    lp.lesson_plan_skills.create!(
      skill: skill,
      role: "main",
      position: idx + 1
    )
  end

  next if lp.lesson_plan_occurrences.exists?

  rand(2..6).times do
    taught_on = rand_date_within(days_forward: 30)
    start_str, end_str = rand_time_range

    lp.lesson_plan_occurrences.create!(
      taught_on: taught_on,
      starts_at: start_str,
      ends_at: end_str,
      location: LOCATIONS.sample
    )
  end
end

puts "✅ Seeded #{LessonPlan.count} lesson plans"
puts "✅ Seeded #{LessonPlanOccurrence.count} lesson plan occurrences"

# =========================
# Rosters + Schedules
# =========================
puts "🌱 Seeding rosters + schedules..."

students = teacher.students.limit(40).to_a

roster_configs = [
  { name: "Sat AM Group", weekday: 6, starts_at: "09:00", ends_at: "10:00", location: "Main Rink" },
  { name: "Basic 2", weekday: 2, starts_at: "16:00", ends_at: "17:00", location: "Practice Rink" },
  { name: "Private Students", weekday: 4, starts_at: "17:00", ends_at: "18:00", location: "Studio Ice" },
  { name: "Power + Edges", weekday: 0, starts_at: "11:00", ends_at: "12:00", location: "North Arena" }
]

roster_configs.each do |config|
  roster = Roster.find_or_initialize_by(teacher: teacher, name: config[:name])
  roster.save!

  roster.students = students.sample(rand(6..14))

  schedule = roster.roster_schedules.first_or_initialize
  schedule.weekday = config[:weekday]
  schedule.starts_at = config[:starts_at]
  schedule.ends_at = config[:ends_at]
  schedule.location = config[:location]
  schedule.save!
end

puts "✅ Seeded #{Roster.count} rosters with students"
puts "✅ Seeded #{RosterSchedule.count} roster schedules"