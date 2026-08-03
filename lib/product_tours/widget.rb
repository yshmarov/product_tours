# frozen_string_literal: true

require 'digest'
require 'json'

module ProductTours
  module Widget
    SOURCE = File.expand_path('widget.js', __dir__)
    DASHBOARD_SOURCE = File.expand_path('dashboard.js', __dir__)
    DASHBOARD_STYLESHEET_SOURCE = File.expand_path('dashboard.css', __dir__)
    RTL_LANGUAGES = %w[ar arc ckb dv fa ha he ks ku ps sd ug ur yi].freeze

    class << self
      def javascript = @javascript ||= File.read(SOURCE)
      def dashboard_javascript = @dashboard_javascript ||= File.read(DASHBOARD_SOURCE)
      def dashboard_stylesheet = @dashboard_stylesheet ||= File.read(DASHBOARD_STYLESHEET_SOURCE)
      def fingerprint = @fingerprint ||= Digest::MD5.hexdigest(javascript)
      def dashboard_fingerprint = @dashboard_fingerprint ||= Digest::MD5.hexdigest(dashboard_javascript)
      def dashboard_stylesheet_fingerprint = @dashboard_stylesheet_fingerprint ||= Digest::MD5.hexdigest(dashboard_stylesheet)

      def snippet(locale:, nonce: nil)
        nonce_attr = nonce ? %( nonce="#{ERB::Util.html_escape(nonce)}") : ''
        source = "#{ProductTours.config.mount_path.to_s.chomp('/')}/widget.js?v=#{fingerprint}"
        %(<script type="application/json" data-product-tours-config>#{config_json(locale:)}</script>) +
          %(<script src="#{ERB::Util.html_escape(source)}" defer#{nonce_attr} data-product-tours-widget></script>)
      end

      def config_json(locale:)
        {
          endpoint: ProductTours.config.widget_endpoint,
          locale: locale.to_s,
          rtl: rtl?(locale),
          labels: labels
        }.to_json.gsub('</', '<\\/')
      end

      private

      def labels
        {
          close: t(:close, 'Close'),
          back: t(:back, 'Back'),
          done: t(:done, 'Done'),
          dialog: t(:dialog, 'Product tutorial'),
          video: t(:video, 'Tutorial video'),
          unavailable: t(:unavailable, 'This tutorial is unavailable.')
        }
      end

      def t(key, default)
        I18n.t(key, scope: :product_tours, default: default)
      end

      def rtl?(locale)
        RTL_LANGUAGES.include?(locale.to_s.downcase.split(/[-_]/).first)
      end
    end
  end
end
