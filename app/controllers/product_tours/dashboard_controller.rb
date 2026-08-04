# frozen_string_literal: true

module ProductTours
  # Root of the STAFF surface: the post editor and its list.
  #
  # Inherits from `config.base_controller_class` — by default a plain
  # ActionController::Base, which is why `authorize_admin` exists. Point it at
  # the controller your own admin already inherits from and the dashboard picks
  # up that stack wholesale: your layout, your helpers, your authentication, and
  # whatever request context your before_actions establish. `config.admin_layout`
  # only ever solved the first of those.
  #
  # Only the dashboard hangs off it. The widget's endpoints stay on
  # ApplicationController, so wiring an admin base controller here can never
  # demand a staff session from a visitor being shown a tour.
  class DashboardController < ProductTours.base_controller
    include RequestContext

    # A host base controller brings its own layout, and declaring one here would
    # override it. So the gem only claims the layout when it owns the decision:
    # no host base controller, or a host that named an `admin_layout` explicitly.
    layout :product_tours_admin_layout unless superclass != ActionController::Base &&
                                              ProductTours.config.admin_layout ==
                                              Configuration::DEFAULT_ADMIN_LAYOUT

    before_action :require_admin

    # A host base controller has configured CSRF already; declaring it twice
    # would run the check twice.
    protect_from_forgery with: :exception if superclass == ActionController::Base
  end
end
