# frozen_string_literal: true

module ProductTours
  module WidgetHelper
    def product_tours_tag
      return unless ProductTours.enabled?(request)

      ProductTours::Widget.snippet(
        locale: ProductTours.locale(request),
        nonce: (content_security_policy_nonce if respond_to?(:content_security_policy_nonce))
      ).html_safe
    end
  end
end
