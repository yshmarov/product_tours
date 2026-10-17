# frozen_string_literal: true

require 'rails'

module ProductTours
  class Engine < ::Rails::Engine
    initializer 'product_tours.ractor_middleware' do |app|
      app.middleware.insert_before 0, RactorSupport::Middleware
    end

    isolate_namespace ProductTours

    initializer 'product_tours.ractorize', before: 'action_controller.ractorize' do
      if Rails::Application.method_defined?(:ractorize!)
        Engine.routes.singleton_class.prepend(RactorSupport::MountedRoutes)
      end

      ActiveSupport.on_load(:before_ractorize) { ProductTours::RactorSupport.prepare! }
    end

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
