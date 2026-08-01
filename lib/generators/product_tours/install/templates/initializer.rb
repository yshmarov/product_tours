# frozen_string_literal: true

ProductTours.configure do |config|
  # Who can see and invoke product tours. Defaults to everyone.
  # config.enabled = ->(request) { true }

  # Who can manage posts at the mount path. Defaults to development only.
  # config.authorize_admin = ->(request) { request.env["warden"]&.user&.admin? }

  # Render the dashboard in your own admin shell.
  # config.admin_layout = "admin/application"

  # Optional request context for lifecycle notifications.
  # config.current_user = ->(request) { request.env["warden"]&.user }
  # config.user_label = ->(user) { user.name.presence || user.email }
  # config.tenant = ->(_request) { Current.organization&.to_gid&.to_s }

  # Locale used to resolve [locale, key]. There is no fallback in v0.1.
  # config.locale = ->(_request) { I18n.locale }

  # Optional dedicated Active Storage service for uploaded videos.
  # config.storage_service = :product_tours

  # Public endpoint throttle on Rails 7.2+; ignored on Rails 7.1.
  # config.rate_limit = { to: 60, within: 1.minute }

  # Invalid, missing, draft, or disabled triggers raise in development/test
  # and are reported through Rails.error plus ActiveSupport::Notifications in production.
  # config.raise_on_unresolved_trigger = ->(_request) { Rails.env.development? || Rails.env.test? }

  # Keep this in sync only when mounting the engine manually.
  # config.mount_path = "/product_tours"
end
