
if Rails.env.production?
  Rails.application.config.session_store :cookie_store,
    key: "_authentication_app",
    domain: "glisse-frontend.onrender.com/",
    secure: true,
    same_site: :lax
else
  Rails.application.config.session_store :cookie_store,
    key: "_authentication_app",
    same_site: :lax
end

Rails.application.config.session_store :cookie_store,
  key: "_project_skate_session",
  same_site: :none,
  secure: Rails.env.production?


