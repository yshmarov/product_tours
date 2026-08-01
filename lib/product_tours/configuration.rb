# frozen_string_literal: true

module ProductTours
  class Configuration
    attr_accessor :enabled, :authorize_admin, :admin_layout, :current_user,
                  :user_label, :tenant, :locale, :mount_path, :rate_limit,
                  :storage_service, :raise_on_unresolved_trigger

    def initialize
      @enabled = ->(_request) { true }
      @authorize_admin = ->(_request) { Rails.env.development? }
      @admin_layout = 'product_tours/application'
      @current_user = ->(_request) {}
      @user_label = lambda do |user|
        user.try(:name).presence || user.try(:email).presence || user&.to_s
      end
      @tenant = ->(_request) {}
      @locale = ->(_request) { I18n.locale }
      @mount_path = '/product_tours'
      @rate_limit = { to: 60, within: 1.minute }
      @storage_service = nil
      @raise_on_unresolved_trigger = ->(_request) { Rails.env.development? || Rails.env.test? }
    end

    def widget_endpoint = "#{mount_path.to_s.chomp('/')}/widget"
  end
end
