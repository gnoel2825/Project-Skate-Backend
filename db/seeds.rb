users = [
  { email: "test@example.com",  first_name: "Test",  last_name: "User" },
  { email: "debug@example.com", first_name: "Debug", last_name: "User" },
  { email: "x@example.com",     first_name: "X",     last_name: "User" }
]

users.each do |attrs|
  user = User.find_or_initialize_by(email: attrs[:email])

  user.update!(
    first_name: attrs[:first_name],
    last_name: attrs[:last_name],
    password: "password",
    password_confirmation: "password",
    role: (attrs[:email] == "test@example.com" ? "teacher" : user.role) # ✅ ensure test is teacher
  )
end

puts "Seeded #{User.count} users."

test_email = "test@example.com"

u = User.find_or_initialize_by(email: test_email)

u.role = "admin"           if u.respond_to?(:role=)
u.save!

puts "Seeded admin user: #{u.email} (id=#{u.id}, role=#{u.role})"


skills = [
  # ===== BASIC 1 =====
  { level: 1, name: "Sit on ice and stand up" },
  { level: 1, name: "March forward across the ice" },
  { level: 1, name: "Forward two-foot glide" },
  { level: 1, name: "Dip" },
  { level: 1, name: "Forward swizzles (6–8 in a row)" },
  { level: 1, name: "Backward wiggles (6–8 in a row)" },
  { level: 1, name: "Beginning snowplow stop (two feet or one foot)" },
  { level: 1, name: "Bonus: Two-foot hop in place" },

  # ===== BASIC 2 =====
  { level: 2, name: "Scooter pushes (R and L)" },
  { level: 2, name: "Forward one-foot glides (R and L)" },
  { level: 2, name: "Backward two-foot glide (length of skater’s height)" },
  { level: 2, name: "Rocking Horse (forward + backward swizzle, repeat twice)" },
  { level: 2, name: "Backward swizzles (6–8 in a row)" },
  { level: 2, name: "Two-foot turns forward to backward (CW and CCW)" },
  { level: 2, name: "Moving snowplow stop" },
  { level: 2, name: "Bonus: Curves" },

  # ===== BASIC 3 =====
  { level: 3, name: "Beginning forward stroking (correct blade use)" },
  { level: 3, name: "Forward half swizzle pumps on a circle (CW & CCW)" },
  { level: 3, name: "Moving forward to backward two-foot turns on a circle" },
  { level: 3, name: "Beginning backward one-foot glides (balance focus)" },
  { level: 3, name: "Backward snowplow stop (R and L)" },
  { level: 3, name: "Forward slalom" },
  { level: 3, name: "Bonus: Forward pivots (CW and CCW)" },

  # ===== BASIC 4 =====
  { level: 4, name: "Forward outside edge on a circle (R and L)" },
  { level: 4, name: "Forward inside edge on a circle (R and L)" },
  { level: 4, name: "Forward crossovers (CW and CCW)" },
  { level: 4, name: "Backward half swizzle pumps on a circle (CW & CCW)" },
  { level: 4, name: "Backward one-foot glides (R and L)" },
  { level: 4, name: "Beginning two-foot spin (up to 2 revs)" },
  { level: 4, name: "Bonus: Forward lunges (both legs)" },

  # ===== BASIC 5 =====
  { level: 5, name: "Backward outside edge on a circle (R and L)" },
  { level: 5, name: "Backward inside edge on a circle (R and L)" },
  { level: 5, name: "Backward crossovers (CW and CCW)" },
  { level: 5, name: "Forward outside three-turn (R and L)" },
  { level: 5, name: "Advanced two-foot spin (4–6 revs)" },
  { level: 5, name: "Hockey stop (both directions)" },
  { level: 5, name: "Bonus: Side toe hop (R and L)" },

  # ===== BASIC 6 =====
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
  Skill.find_or_create_by!(name: skill[:name]) do |s|
    s.level = skill[:level]
    s.is_active = true
  end
end

puts "✅ Seeded #{Skill.count} skills"

puts "🌱 Seeding students..."

# Find or create a teacher
teacher = User.find_by!(email: "test@example.com")

# If you want to be extra safe:
teacher.update!(role: "teacher") if teacher.role != "teacher"

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
  last  = LAST_NAMES.sample

  Student.create!(
    teacher: teacher,
    first_name: first,
    last_name: last,
    email: "#{first.downcase}.#{last.downcase}#{i}@student.com",
    birthday: Date.today - rand(6..16).years,
    notes: ["Focus on edges", "Working on spins", "Needs confidence", nil].sample
  )
end

puts "✅ Seeded 100 students for #{teacher.email}"

puts "🌱 Seeding lesson plans + occurrences..."

teacher = User.find_by!(email: "test@example.com")
teacher.update!(role: "teacher") if teacher.respond_to?(:role) && teacher.role != "teacher"

# Optional: wipe existing lesson plans/occurrences for a clean re-seed
# LessonPlanOccurrence.delete_all
# LessonPlan.delete_all

SKILL_POOL = Skill.all.to_a
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
  # 30/45/60 min lessons starting between 3pm–8pm
  start_hour = rand(15..20)
  start_min  = [0, 15, 30, 45].sample
  duration  = [30, 45, 60].sample

  start_str = format("%02d:%02d", start_hour, start_min)
  # compute end
  end_minutes = (start_hour * 60 + start_min + duration)
  end_hour = end_minutes / 60
  end_min  = end_minutes % 60
  end_str  = format("%02d:%02d", end_hour, end_min)

  [start_str, end_str]
end

lesson_plans_to_create = 30

lesson_plans_to_create.times do |i|
  title = "#{PLAN_TITLES.sample} ##{i + 1}"
  desc  = PLAN_DESCRIPTIONS.sample

  lp = LessonPlan.create!(
    teacher: teacher,
    title: title,
    description: desc
  )

  # Attach 4–10 random skills
  lp.skills << SKILL_POOL.sample(rand(4..10))

  # Create 2–6 occurrences per plan
  rand(2..6).times do
    taught_on = rand_date_within(days_forward: 30)
    start_str, end_str = rand_time_range

    # IMPORTANT:
    # Depending on your DB column type, starts_at/ends_at might be :time or :datetime.
    # Try the "time-only" version first. If you get errors, switch to the datetime version below.

    occ_attrs = {
      taught_on: taught_on,
      starts_at: start_str,   # ✅ works if starts_at is a time column
      ends_at: end_str,       # ✅ works if ends_at is a time column
      location: LOCATIONS.sample
    }

    # If your columns are datetime instead of time, use this instead:
    # occ_attrs[:starts_at] = Time.zone.parse("#{taught_on} #{start_str}")
    # occ_attrs[:ends_at]   = Time.zone.parse("#{taught_on} #{end_str}")

    lp.lesson_plan_occurrences.create!(occ_attrs)
  end
end

puts "✅ Seeded #{LessonPlan.count} lesson plans"
puts "✅ Seeded #{LessonPlanOccurrence.count} lesson plan occurrences"

teacher = User.find_by!(email: "test@example.com")
students = teacher.students.limit(40).to_a

["Sat AM Group", "Basic 2", "Private Students", "Power + Edges"].each do |name|
  r = teacher.rosters.create!(name: name)
  r.students << students.sample(rand(6..14))
end
puts "✅ Seeded #{Roster.count} rosters with students"
puts "🌱 Seeding complete!"

teachers = [
  { first_name: "Ava",   last_name: "Nguyen",  email: "ava.nguyen@example.com",  password: "password" },
  { first_name: "Maya",  last_name: "Patel",   email: "maya.patel@example.com", password: "password" },
  { first_name: "Jordan",last_name: "Kim",     email: "jordan.kim@example.com", password: "password" },
  { first_name: "Elena", last_name: "Garcia",  email: "elena.garcia@example.com", password: "password" },
]

teachers.each do |t|
  user = User.find_or_initialize_by(email: t[:email])
  user.assign_attributes(t.merge(role: "teacher"))
  user.save!
end

puts "Seeded #{teachers.length} teachers"
