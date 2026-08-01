# frozen_string_literal: true

module ProductTours
  class Error < StandardError; end

  class UnresolvedTriggerError < Error
    attr_reader :payload

    def initialize(payload)
      @payload = payload
      super("Product tour #{payload[:key].inspect} could not be resolved (#{payload[:reason]})")
    end
  end
end
