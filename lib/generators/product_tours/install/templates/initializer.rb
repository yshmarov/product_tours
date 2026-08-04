# frozen_string_literal: true

ProductTours.configure do |config|
  # Who can see and invoke product tours. Defaults to everyone.
  # config.enabled = ->(request) { true }

  # Who can manage tutorials at the mount path. Defaults to development only.
  # config.authorize_admin = ->(request) { request.env["warden"]&.user&.admin? }

  # Render the dashboard in your own admin shell.
  # Two ways to put the dashboard inside an admin you already have.
  #
  # The whole stack — your layout, helpers, authentication and any request
  # context your before_actions set up. Only the dashboard inherits it; the
  # widget's endpoints stay public, so this cannot gate a visitor's tour.
  # config.base_controller_class = "Admin::BaseController"
  #
  # Or the layout alone:
  # config.admin_layout = "admin/application"

  # Tutorials resolve in the page's current I18n.locale and fall back to
  # I18n.default_locale when no translation exists.

  # Optional dedicated Active Storage service for uploaded videos.
  # config.storage_service = :product_tours

  # Keep this in sync only when mounting the engine manually.
  # config.mount_path = "/product_tours"
end
