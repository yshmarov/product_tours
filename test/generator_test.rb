# frozen_string_literal: true

require 'test_helper'
require 'rails/generators/test_case'
require 'generators/product_tours/install/install_generator'

class InstallGeneratorTest < Rails::Generators::TestCase
  tests ProductTours::Generators::InstallGenerator
  destination File.expand_path('tmp/generator', __dir__)
  setup :prepare_destination

  test 'creates initializer, migration, and mount route' do
    FileUtils.mkdir_p(File.join(destination_root, 'config'))
    File.write(File.join(destination_root, 'config/routes.rb'), "Rails.application.routes.draw do\nend\n")

    run_generator

    assert_file 'config/initializers/product_tours.rb', /config\.on_event/
    assert_migration 'db/migrate/create_product_tours_posts.rb' do |migration|
      assert_includes migration, 'create_table :product_tours_posts'
      assert_includes migration, '%i[locale key], unique: true'
      assert_includes migration, 't.string :action_post_key'
      assert_includes migration, 'ProductTours::Seeds.load_for_install!'
    end
    assert_file 'config/routes.rb', %r{mount_product_tours at: "/product_tours"}
  end
end
