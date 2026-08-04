# frozen_string_literal: true

module ProductTours
  class Configuration
    # The gem's own dashboard layout. Compared against, so DashboardController
    # can tell "the host left this alone" from "the host chose this".
    DEFAULT_ADMIN_LAYOUT = 'product_tours/application'

    attr_accessor :enabled, :authorize_admin, :admin_layout, :mount_path,
                  :storage_service

    # The controller the DASHBOARD inherits from, as a String so it resolves
    # lazily rather than at config time. Default: a plain
    # 'ActionController::Base', where `authorize_admin` is the only gate.
    #
    # Name the controller your own admin already inherits from and the dashboard
    # adopts that whole stack — layout, helpers, authentication, and any request
    # context your before_actions set up. `admin_layout` covers only the layout,
    # which leaves a host layout calling its own helpers to raise NameError under
    # the engine's isolated namespace.
    #
    # Only the dashboard uses it. The widget's endpoints stay on the engine's own
    # public controller, so an admin base controller here can never demand a
    # staff session from a visitor being shown a tour.
    attr_accessor :base_controller_class

    def initialize
      @enabled = ->(_request) { true }
      @authorize_admin = ->(_request) { Rails.env.development? }
      @admin_layout = DEFAULT_ADMIN_LAYOUT
      @base_controller_class = 'ActionController::Base'
      @mount_path = '/product_tours'
      @storage_service = nil
    end

    def widget_endpoint = "#{mount_path.to_s.chomp('/')}/widget"
  end
end
