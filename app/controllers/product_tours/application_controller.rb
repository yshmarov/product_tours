# frozen_string_literal: true

module ProductTours
  # Root of the engine's PUBLIC surface: widget.js, tour resolution, signals and
  # media. These stay on a plain ActionController::Base deliberately — a visitor
  # loading a tour must not be routed through a host's admin controller, which
  # would demand a staff session for the widget.
  #
  # The dashboard's root is DashboardController, and that is where
  # `config.base_controller_class` applies.
  class ApplicationController < ActionController::Base
    include RequestContext

    protect_from_forgery with: :exception
  end
end
