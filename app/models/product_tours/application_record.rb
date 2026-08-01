# frozen_string_literal: true

module ProductTours
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true
  end
end
