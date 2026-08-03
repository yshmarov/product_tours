# frozen_string_literal: true

namespace :product_tours do
  desc 'Create or refresh the multilingual product_tours demo posts'
  task seed_demo: :environment do
    posts = ProductTours::Seeds.load_all!
    locales = ProductTours::Seeds::DEMO_LOCALES.join(', ')
    puts "Seeded #{posts.size} product tour demo posts for #{locales}."
    puts "\nCopy this into any ERB view to try them:\n\n"
    puts ProductTours::Seeds.trigger_html
  end
end
