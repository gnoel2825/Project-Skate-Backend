class User < ApplicationRecord
  has_secure_password
  has_one_attached :icon
  has_many :students, foreign_key: :teacher_id, dependent: :destroy
  has_many :rosters, foreign_key: :teacher_id, dependent: :destroy
  has_many :lesson_plans, foreign_key: :teacher_id, dependent: :destroy
  has_many :owned_students, class_name: "Student", foreign_key: :teacher_id, dependent: :destroy
  has_many :roster_teachings, class_name: "RosterTeacher", foreign_key: :teacher_id, dependent: :destroy
  has_many :taught_rosters, through: :roster_teachings, source: :roster

  before_create :ensure_auth_token
  after_create_commit :attach_default_icon


  ROLES = %w[none teacher admin].freeze

  validates :email, presence: true, uniqueness: true
  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :role, inclusion: { in: ROLES }
  validate :icon_validation

  def teacher?
    role == "teacher" || role == "admin"
  end

  def admin?
  role == "admin"
end

  def icon_validation
    return unless icon.attached?

    if icon.byte_size > 1.megabyte
      errors.add(:icon, "must be less than 1MB")
    end

    acceptable_types = [ "image/jpeg", "image/png", "image/webp" ]
    unless acceptable_types.include?(icon.content_type)
      errors.add(:icon, "must be a JPEG, PNG, or WebP")
    end
  end


  def welcome
    "Hello, #{email}!"
  end

     def ensure_auth_token
    self.auth_token ||= SecureRandom.hex(32)
  end

  def reset_auth_token!
    update!(auth_token: SecureRandom.hex(32))
  end


   private

  def attach_default_icon
    return if icon.attached?

    icon.attach(
      io: File.open(
        Rails.root.join("app/assets/imgs/defaults/defaulticon.png")
      ),
      filename: "default-user-icon.png",
      content_type: "image/png"
    )
  end
end
