# frozen_string_literal: true

require 'uri'

module ProductTours
  class VideoResolver
    Result = Data.define(:kind, :provider, :provider_id, :url) do
      def iframe? = kind == 'iframe'
      def direct? = kind == 'direct'

      def metadata
        {
          'provider' => provider,
          'provider_id' => provider_id,
          'embed_url' => iframe? ? url : nil
        }.compact
      end
    end

    YOUTUBE_HOSTS = %w[youtube.com www.youtube.com m.youtube.com youtu.be youtube-nocookie.com
                       www.youtube-nocookie.com].freeze
    VIMEO_HOSTS = %w[vimeo.com www.vimeo.com player.vimeo.com].freeze
    LOOM_HOSTS = %w[loom.com www.loom.com].freeze
    TELLA_HOSTS = %w[tella.tv www.tella.tv].freeze
    VOOMLY_HOSTS = %w[share.voomly.com embed.voomly.com app.voomly.com voomly.com www.voomly.com].freeze

    def self.resolve(url)
      new(url).resolve
    end

    def initialize(url)
      @url = url.to_s.strip
    end

    def resolve
      uri = URI.parse(@url)
      return unless uri.is_a?(URI::HTTPS) && uri.host.present? && uri.userinfo.nil?

      case uri.host.downcase
      when *YOUTUBE_HOSTS then youtube(uri)
      when *VIMEO_HOSTS then vimeo(uri)
      when *LOOM_HOSTS then loom(uri)
      when *TELLA_HOSTS then tella(uri)
      when *VOOMLY_HOSTS then voomly(uri)
      else direct(uri)
      end
    rescue URI::InvalidURIError, ArgumentError
      nil
    end

    private

    def youtube(uri)
      id = if uri.host.downcase == 'youtu.be'
             segments(uri).first
           elsif uri.path == '/watch'
             query(uri)['v']
           else
             match = uri.path.match(%r{\A/(?:embed|shorts|live)/([A-Za-z0-9_-]+)})
             match && match[1]
           end
      return unless id&.match?(/\A[A-Za-z0-9_-]{6,20}\z/)

      Result.new(kind: 'iframe', provider: 'youtube', provider_id: id,
                 url: "https://www.youtube-nocookie.com/embed/#{id}?rel=0&modestbranding=1")
    end

    def vimeo(uri)
      parts = segments(uri)
      parts.shift if parts.first == 'video'
      id = parts.shift
      return unless id&.match?(/\A\d+\z/)

      privacy_hash = query(uri)['h'].presence || parts.first.to_s.presence
      return if privacy_hash && !privacy_hash.match?(/\A[A-Za-z0-9]+\z/)

      embed_url = "https://player.vimeo.com/video/#{id}"
      embed_url += "?h=#{URI.encode_www_form_component(privacy_hash)}" if privacy_hash
      Result.new(kind: 'iframe', provider: 'vimeo', provider_id: id, url: embed_url)
    end

    def loom(uri)
      match = uri.path.match(%r{\A/(?:share|embed)/([A-Za-z0-9_-]{8,64})/?\z})
      return unless match

      id = match[1]
      Result.new(kind: 'iframe', provider: 'loom', provider_id: id,
                 url: "https://www.loom.com/embed/#{id}")
    end

    def tella(uri)
      match = uri.path.match(%r{\A/video/([A-Za-z0-9_-]{3,100})(?:/(?:view|embed))?/?\z})
      return unless match

      id = match[1]
      Result.new(kind: 'iframe', provider: 'tella', provider_id: id,
                 url: "https://www.tella.tv/video/#{id}/embed")
    end

    def voomly(uri)
      id = if uri.host.downcase == 'embed.voomly.com' && uri.path == '/embed/assets/embed.html'
             query(uri)['videoId']
           else
             uri.path.match(%r{\A/(?:v|video)/([A-Za-z0-9_-]{6,160})/?\z})&.[](1)
           end
      return unless id&.match?(/\A[A-Za-z0-9_-]{6,160}\z/)

      embed = 'https://embed.voomly.com/embed/assets/embed.html?' \
              "videoId=#{URI.encode_www_form_component(id)}&videoRatio=1.777778&type=v"
      Result.new(kind: 'iframe', provider: 'voomly', provider_id: id, url: embed)
    end

    def direct(uri)
      return unless uri.path.match?(/\.(?:mp4|webm)\z/i)

      Result.new(kind: 'direct', provider: 'direct', provider_id: nil, url: uri.to_s)
    end

    def segments(uri)
      uri.path.split('/').reject(&:blank?)
    end

    def query(uri)
      URI.decode_www_form(uri.query.to_s).to_h
    rescue ArgumentError
      {}
    end
  end
end
