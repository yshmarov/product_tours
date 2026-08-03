# frozen_string_literal: true

module ProductTours
  module ContentSecurityPolicy
    FRAME_SOURCES = %w[
      https://www.youtube-nocookie.com
      https://player.vimeo.com
      https://www.loom.com
      https://www.tella.tv
      https://embed.voomly.com
    ].freeze

    module_function

    def apply!(policy)
      return unless policy

      sources = Array(policy.directives['frame-src'])
      sources = Array(policy.directives['default-src']) if sources.empty?
      sources = sources.reject { |source| source == "'none'" }
      policy.frame_src(*(sources + FRAME_SOURCES).uniq)
    end
  end
end
