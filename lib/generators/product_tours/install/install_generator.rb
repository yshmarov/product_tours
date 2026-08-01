# frozen_string_literal: true

require 'rails/generators'
require 'rails/generators/active_record'

module ProductTours
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include ActiveRecord::Generators::Migration

      source_root File.expand_path('templates', __dir__)
      desc 'Installs product_tours: initializer, posts migration, and engine mount.'

      def create_initializer
        copy_file 'initializer.rb', 'config/initializers/product_tours.rb'
      end

      def create_migration_file
        migration_template 'create_product_tours_posts.rb.tt', 'db/migrate/create_product_tours_posts.rb'
      end

      def mount_engine
        route %(mount_product_tours at: "/product_tours")
      end

      def post_install
        say "\nproduct_tours installed. Run `bin/rails db:migrate`, then add", :green
        say '`<%= product_tours_tag %>` before </body> in your application layout.'
        say 'Manage posts at /product_tours (development only until config.authorize_admin is set).'
        say 'Optional: run `bin/rails product_tours:seed_demo` for provider demo posts.'
        say 'Run `bin/rails active_storage:install` for uploads and '
        say '`bin/rails action_text:install` for rich descriptions.\n'
      end

      private

      def migration_version
        "[#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}]"
      end
    end
  end
end
