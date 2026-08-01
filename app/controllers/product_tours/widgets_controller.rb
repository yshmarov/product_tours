# frozen_string_literal: true

module ProductTours
  class WidgetsController < ApplicationController
    skip_forgery_protection

    def show
      serve(Widget.javascript, Widget.fingerprint)
    end

    def dashboard
      serve(Widget.dashboard_javascript, Widget.dashboard_fingerprint, 'text/javascript')
    end

    def dashboard_stylesheet
      serve(Widget.dashboard_stylesheet, Widget.dashboard_stylesheet_fingerprint, 'text/css')
    end

    private

    def serve(source, fingerprint, content_type = 'text/javascript')
      expires_in 1.year, public: true if params[:v] == fingerprint
      return unless stale?(etag: [ProductTours::VERSION, fingerprint])

      render plain: source, content_type: content_type
    end
  end
end
