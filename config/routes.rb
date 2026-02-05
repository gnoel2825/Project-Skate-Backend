Rails.application.routes.draw do
  # Auth / session endpoints for React
  post   "/registrations", to: "registrations#create"
  post   "/sessions",      to: "sessions#create"
  delete "/logout",        to: "sessions#destroy"
  get    "/logged_in",     to: "sessions#logged_in"
  patch  "/password",      to: "passwords#update"
  patch  "/profile",       to: "users#update"

  # Lesson Plans
  resources :lesson_plans, only: [:create, :show, :index, :update, :destroy] do
    post :add_skills, on: :member
    delete "remove_skill/:skill_id", to: "lesson_plans#remove_skill", on: :member
    resources :lesson_plan_occurrences, only: [:create, :update, :destroy]
  end

  # Calendar query
  get "/lesson_plans_by_date", to: "lesson_plan_occurrences#by_date"

  # Skills
  resources :skills, only: [:index, :show, :create, :update, :destroy]

  # Users
  resources :users, only: [:index, :show, :create, :update]
  delete "/account", to: "users#destroy"

  namespace :admin do
  resources :users, only: [:index, :create, :update, :destroy]
end

  # Students
  resources :students, only: [:index, :show, :create, :update, :destroy] do
  collection do
    get :owned
    get :all
  end
end

get "/students_from_rosters", to: "students#from_rosters"



  # Rosters
  resources :rosters do
    post   "add_student/:student_id",    to: "rosters#add_student"
    delete "remove_student/:student_id", to: "rosters#remove_student"
   
  member do
    get :available_students
    delete "remove_teacher/:teacher_id", to: "rosters#remove_teacher"
    post   "add_teacher/:teacher_id",    to: "rosters#add_teacher"
  end

    resources :roster_meetings, only: [:create, :update, :destroy]
    resources :roster_schedules, only: [:index, :create, :update, :destroy]

    get :scheduled_lessons, on: :member
    get :upcoming_scheduled_lessons, on: :member
    get :lesson_plans_in_week, on: :member
    get :lesson_plans_matching_schedule, on: :member
  end

  get "/rosters_by_date", to: "rosters#by_date"
  get "/roster_meetings_by_date", to: "roster_meetings#by_date"

  get "/my_students", to: "students#my_students"


  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
end
