# frozen_string_literal: true

require 'rails/generators'
require 'rails/generators/active_record'
require_relative '../migration_helpers'

module ProductTours
  module Generators
    # Brings an install created by an earlier version up to the current schema.
    # Every migration it writes checks before it changes anything, so running it
    # on an app that is already current is harmless.
    class UpgradeGenerator < Rails::Generators::Base
      include ActiveRecord::Generators::Migration
      include MigrationHelpers

      source_root File.expand_path('templates', __dir__)
      desc 'Adds the columns newer product_tours versions use to an existing install.'

      def create_player_media_migration
        migration_template 'add_player_media_to_product_tours_tours.rb.tt',
                           'db/migrate/add_player_media_to_product_tours_tours.rb', skip: true
      end

      def post_upgrade
        say "\nRun `bin/rails db:migrate` to finish the product_tours upgrade.", :green
      end
    end
  end
end
