# frozen_string_literal: true

module ProductTours
  class Engine < ::Rails::Engine
    isolate_namespace ProductTours

    rake_tasks do
      load File.expand_path('../tasks/product_tours_tasks.rake', __dir__)
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
  end
end
