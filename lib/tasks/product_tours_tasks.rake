# frozen_string_literal: true

namespace :product_tours do
  desc 'Create or refresh the multilingual product_tours demo tours'
  task seed_demo: :environment do
    tours = ProductTours::Seeds.load_all!
    locales = ProductTours::Seeds::DEMO_LOCALES.join(', ')
    puts "Seeded #{tours.size} product tour demo tours for #{locales}."
    puts "\nCopy this into any ERB view to try them:\n\n"
    puts ProductTours::Seeds.trigger_html
  end
end
