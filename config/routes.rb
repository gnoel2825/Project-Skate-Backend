Rails.application.routes.draw do
  post   "/registrations", to: "registrations#create"
  post   "/sessions",      to: "sessions#create"
  delete "/logout",        to: "sessions#destroy"
  get    "/logged_in",     to: "sessions#logged_in"
  patch  "/password",      to: "passwords#update"
  patch  "/profile",       to: "users#update"

  resources :lesson_plans, only: [ :create, :show, :index, :update, :destroy ] do
    member do
      post :add_skills
      delete "remove_skill/:skill_id", to: "lesson_plans#remove_skill"
      post :duplicate
    end

    resources :lesson_plan_occurrences, only: [ :create, :update, :destroy ]
  end

  resources :lesson_plan_occurrences, only: [] do
    resources :attendances, only: [ :index, :create, :update ]
  end

  get "/lesson_plans_by_date", to: "lesson_plan_occurrences#by_date"

  resources :skills, only: [ :index, :show, :create, :update, :destroy ]

  resources :users, only: [ :index, :show, :create, :update ]
  delete "/account", to: "users#destroy"

  namespace :admin do
    resources :users, only: [ :index, :create, :update, :destroy ]
  end

  resources :students, only: [ :index, :show, :create, :update, :destroy ] do
    collection do
      get :owned
      get :all
    end
  end

  get "/students_from_rosters", to: "students#from_rosters"
  get "/my_students", to: "students#my_students"

  resources :rosters do
  post   "add_student/:student_id",    to: "rosters#add_student"
  delete "remove_student/:student_id", to: "rosters#remove_student"

  member do
    get :available_students
    delete "remove_teacher/:teacher_id", to: "rosters#remove_teacher"
    post   "add_teacher/:teacher_id",    to: "rosters#add_teacher"
    get :scheduled_lessons
    get :upcoming_scheduled_lessons
    get :lesson_plans_in_week
    get :lesson_plans_matching_schedule
    get :upcoming_slots
  end

  resources :roster_meetings, only: [ :create, :update, :destroy ]
  resources :roster_schedules, only: [ :index, :create, :update, :destroy ]
end

  get "/rosters_by_date", to: "rosters#by_date"
  get "/roster_meetings_by_date", to: "roster_meetings#by_date"

  get "up" => "rails/health#show", as: :rails_health_check
  get "/version", to: proc { [ 200, { "Content-Type" => "application/json" }, [ { sha: ENV["RENDER_GIT_COMMIT"] || "unknown" }.to_json ] ] }
end
