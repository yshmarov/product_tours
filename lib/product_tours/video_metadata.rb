# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'

module ProductTours
  class VideoMetadata
    ENDPOINTS = {
      'youtube' => 'https://www.youtube.com/oembed',
      'vimeo' => 'https://vimeo.com/api/oembed.json',
      'loom' => 'https://www.loom.com/v1/oembed'
    }.freeze

    def self.fetch(url)
      new(url).fetch
    end

    def initialize(url)
      @url = url.to_s
    end

    def fetch
      resolved = VideoResolver.resolve(@url)
      return {} unless resolved

      metadata = resolved.metadata
      endpoint = ENDPOINTS[resolved.provider]
      return metadata unless endpoint

      response = request(endpoint)
      return metadata unless response.is_a?(Net::HTTPSuccess)

      body = JSON.parse(response.body)
      metadata.merge(
        'provider_title' => body['title'].presence,
        'thumbnail_url' => safe_https_url(body['thumbnail_url'])
      ).compact
    rescue JSON::ParserError, IOError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError
      metadata || {}
    end

    private

    def request(endpoint)
      uri = URI(endpoint)
      uri.query = URI.encode_www_form(url: @url, format: 'json')
      Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 3, read_timeout: 4) do |http|
        http.get(uri.request_uri, { 'User-Agent' => "product_tours/#{ProductTours::VERSION}" })
      end
    end

    def safe_https_url(value)
      uri = URI.parse(value.to_s)
      uri.to_s if uri.is_a?(URI::HTTPS) && uri.host.present? && uri.userinfo.nil?
    rescue URI::InvalidURIError
      nil
    end
  end
end
