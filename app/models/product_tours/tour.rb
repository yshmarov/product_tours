# frozen_string_literal: true

require 'uri'

module ProductTours
  class Tour < ApplicationRecord
    KEY_FORMAT = /\A[a-z0-9]+(?:[._-][a-z0-9]+)*\z/
    STATUSES = %w[draft published].freeze
    DASHBOARD_STATUSES = %w[published draft].freeze

    enum :status, STATUSES.index_by(&:itself), default: :draft

    # Explicit methods work in non-main Ractors; Rails' enum-generated
    # predicates and bang methods are currently unisolated closures.
    def draft? = status_for_database == 'draft'
    def draft! = update!(status: 'draft')
    def published? = status_for_database == 'published'
    def published! = update!(status: 'published')

    has_rich_text :description if respond_to?(:has_rich_text)

    has_one_attached :video, service: ProductTours.config.storage_service if defined?(::ActiveStorage)

    validates :key, presence: true, format: { with: KEY_FORMAT }, uniqueness: { scope: :locale }
    validates :locale, presence: true
    validates :status, inclusion: { in: STATUSES }
    validates :title, presence: true
    validate :action_has_one_destination
    validate :action_tour_is_linkable
    validate :action_url_is_safe
    validate :video_url_is_supported
    validate :uploaded_file_is_video
    validate :player_media_urls_are_safe
    validate :player_media_has_a_player

    before_validation :set_default_locale
    before_validation :derive_video_metadata, if: :will_save_change_to_video_url?

    scope :newest_first, -> { order(updated_at: :desc, id: :desc) }

    def self.description_supported?
      reflect_on_association(:rich_text_description).present? &&
        ActionText::RichText.table_exists?
    rescue ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid, NameError
      false
    end

    def self.video_upload_supported?
      reflect_on_association(:video_attachment).present? &&
        ActiveStorage::Blob.table_exists? && ActiveStorage::Attachment.table_exists?
    rescue ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid, NameError
      false
    end

    # Added in 1.2. An install from an earlier version has neither column until
    # it runs `bin/rails generate product_tours:upgrade`, and works as before.
    def self.captions_supported?
      column_names.include?('captions_url')
    rescue ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid
      false
    end

    def self.poster_supported?
      column_names.include?('poster_url')
    rescue ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid
      false
    end

    def uploaded_video?
      self.class.video_upload_supported? && video.attached?
    end

    def resolved_video
      return { kind: 'upload', provider: 'upload', url: nil, **player_media } if uploaded_video?

      resolved = VideoResolver.resolve(video_url)
      return if resolved.nil?

      {
        kind: resolved.kind,
        provider: resolved.provider,
        url: resolved.url,
        thumbnail_url: video_metadata.to_h['thumbnail_url'],
        **(resolved.direct? ? player_media : {})
      }.compact
    end

    # The tour's own video player can show a poster and a captions track.
    # Provider iframes cannot: their poster and captions are the provider's.
    def captions_url = (self[:captions_url] if self.class.captions_supported?)
    def poster_url = (self[:poster_url] if self.class.poster_supported?)

    def action_tour
      return if action_tour_key.blank?

      self.class.find_by(locale: locale, key: action_tour_key)
    end

    private

    def set_default_locale
      self.locale = I18n.default_locale.to_s if locale.blank?
    end

    def derive_video_metadata
      resolved = VideoResolver.resolve(video_url)
      self.video_metadata = resolved ? video_metadata.to_h.merge(resolved.metadata) : {}
    end

    def video_url_is_supported
      return if video_url.blank? || VideoResolver.resolve(video_url)

      errors.add(:video_url, 'must be an HTTPS YouTube, Vimeo, Loom, Tella, Voomly, MP4, or WebM URL')
    end

    def action_url_is_safe
      return if action_url.blank?
      return if action_url.start_with?('/') && !action_url.start_with?('//')

      uri = URI.parse(action_url)
      return if uri.is_a?(URI::HTTP) && %w[http https].include?(uri.scheme) && uri.host.present? && uri.userinfo.nil?

      errors.add(:action_url, 'must be a relative path or an HTTP(S) URL')
    rescue URI::InvalidURIError
      errors.add(:action_url, 'must be a relative path or an HTTP(S) URL')
    end

    def action_has_one_destination
      return unless action_url.present? && action_tour_key.present?

      errors.add(:base, 'Primary action can open a URL or another tour, not both')
    end

    def action_tour_is_linkable
      return if action_tour_key.blank?

      unless action_tour_key.match?(KEY_FORMAT)
        errors.add(:action_tour_key, 'must use a valid tour key')
        return
      end
      if action_tour_key == key
        errors.add(:action_tour_key, 'cannot link to the same tour')
        return
      end
      return if locale.blank? || self.class.exists?(locale: locale, key: action_tour_key)

      errors.add(:action_tour_key, 'must identify an existing tour in the same locale')
    end

    def player_media
      { poster_url: poster_url.presence, captions_url: captions_url.presence }.compact
    end

    def player_media_urls_are_safe
      { captions_url: captions_url, poster_url: poster_url }.each do |attribute, value|
        next if value.blank? || safe_media_url?(value)

        errors.add(attribute, 'must be a relative path or an HTTPS URL')
      end
    end

    def player_media_has_a_player
      return if captions_url.blank? && poster_url.blank?
      return if uploaded_video? || VideoResolver.resolve(video_url)&.direct?

      errors.add(:base, 'A poster and captions need a direct MP4/WebM URL or an uploaded video')
    end

    def safe_media_url?(value)
      return !value.start_with?('//') if value.start_with?('/')

      uri = URI.parse(value)
      uri.is_a?(URI::HTTPS) && uri.host.present? && uri.userinfo.nil?
    rescue URI::InvalidURIError
      false
    end

    def uploaded_file_is_video
      return unless uploaded_video?
      return if video.blob.content_type.to_s.start_with?('video/')

      errors.add(:video, 'must be a video file')
    end
  end
end
