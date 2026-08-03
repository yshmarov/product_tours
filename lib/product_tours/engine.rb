# frozen_string_literal: true

require 'rails'

module ProductTours
  class Engine < ::Rails::Engine
    isolate_namespace ProductTours

    initializer 'product_tours.helpers' do
      ActiveSupport.on_load(:action_view) do
        include ProductTours::WidgetHelper
      end
    end

    initializer 'product_tours.routing' do
      ActionDispatch::Routing::Mapper.include(Module.new do
        def mount_product_tours(at: ProductTours.config.mount_path, **options)
          ProductTours.config.mount_path = at
          mount ProductTours::Engine, at:, **options
        end
      end)
    end

    initializer 'product_tours.content_security_policy', after: :load_config_initializers do |app|
      ProductTours::ContentSecurityPolicy.apply!(app.config.content_security_policy)
    end
  end
end
