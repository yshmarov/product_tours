# frozen_string_literal: true

require 'test_helper'
require 'rails/generators/test_case'
require 'generators/product_tours/install/install_generator'
require 'generators/product_tours/upgrade/upgrade_generator'

class InstallGeneratorTest < Rails::Generators::TestCase
  tests ProductTours::Generators::InstallGenerator
  destination File.expand_path('../tmp/generator', __dir__)
  setup :prepare_destination

  test 'creates initializer, migration, and mount route' do
    FileUtils.mkdir_p(File.join(destination_root, 'config'))
    File.write(File.join(destination_root, 'config/routes.rb'), "Rails.application.routes.draw do\nend\n")

    run_generator

    assert_file 'config/initializers/product_tours.rb', /config\.on_event/
    assert_migration 'db/migrate/create_product_tours_tours.rb' do |migration|
      assert_includes migration, 'create_table :product_tours_tours'
      assert_includes migration, '%i[locale key], unique: true'
      assert_includes migration, 't.string :action_tour_key'
      assert_includes migration, 't.text :captions_url'
      assert_includes migration, 'ProductTours::Seeds.load_for_install!'
    end
    assert_file 'config/routes.rb', %r{mount_product_tours at: "/product_tours"}
  end
end

class UpgradeGeneratorTest < Rails::Generators::TestCase
  tests ProductTours::Generators::UpgradeGenerator
  destination File.expand_path('../tmp/generator', __dir__)
  setup :prepare_destination

  test 'adds the player media columns an earlier install lacks, once' do
    run_generator
    run_generator

    assert_migration 'db/migrate/add_player_media_to_product_tours_tours.rb' do |migration|
      assert_includes migration, 'unless column_exists?(:product_tours_tours, column)'
      assert_includes migration, '%i[poster_url captions_url]'
    end
    assert_equal 1, Dir[File.join(destination_root, 'db/migrate/*_add_player_media_to_product_tours_tours.rb')].size
  end
end
