# frozen_string_literal: true

return unless Rails.env.test?

ProductTours.configure do |config|
  config.authorize_admin = ->(_request) { true }
end
