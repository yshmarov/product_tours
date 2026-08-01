# frozen_string_literal: true

return unless Rails.env.test?

ProductTours.configure do |config|
  config.authorize_admin = ->(_request) { true }
  config.raise_on_unresolved_trigger = ->(_request) { false }
end
