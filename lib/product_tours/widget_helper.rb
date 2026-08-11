# frozen_string_literal: true

module ProductTours
  # Included into the host's ActionView. This lives under lib and is required
  # before the engine registers its Action View load hook: a host initializer
  # may load Action View before Rails sets up application autoloaders, when an
  # app/helpers constant cannot be resolved yet.
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
