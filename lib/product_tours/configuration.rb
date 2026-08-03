# frozen_string_literal: true

module ProductTours
  class Configuration
    attr_accessor :enabled, :authorize_admin, :admin_layout, :mount_path,
                  :storage_service

    def initialize
      @enabled = ->(_request) { true }
      @authorize_admin = ->(_request) { Rails.env.development? }
      @admin_layout = 'product_tours/application'
      @mount_path = '/product_tours'
      @storage_service = nil
    end

    def widget_endpoint = "#{mount_path.to_s.chomp('/')}/widget"
  end
end
