# frozen_string_literal: true

require 'uri'

module ProductTours
  class Post < ApplicationRecord
    KEY_FORMAT = /\A[a-z0-9]+(?:[._-][a-z0-9]+)*\z/
    STATUSES = %w[draft published].freeze
    DASHBOARD_STATUSES = %w[published draft].freeze

    enum :status, STATUSES.index_by(&:itself), default: :draft

    has_rich_text :description if respond_to?(:has_rich_text)

    has_one_attached :video, service: ProductTours.config.storage_service if defined?(::ActiveStorage)

    validates :key, presence: true, format: { with: KEY_FORMAT }, uniqueness: { scope: :locale }
    validates :locale, presence: true
    validates :status, inclusion: { in: STATUSES }
    validates :title, presence: true
    validate :action_has_one_destination
    validate :action_post_is_linkable
    validate :action_url_is_safe
    validate :video_url_is_supported
    validate :uploaded_file_is_video

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

    def uploaded_video?
      self.class.video_upload_supported? && video.attached?
    end

    def resolved_video
      return { kind: 'upload', provider: 'upload', url: nil } if uploaded_video?

      resolved = VideoResolver.resolve(video_url)
      return if resolved.nil?

      {
        kind: resolved.kind,
        provider: resolved.provider,
        url: resolved.url,
        thumbnail_url: video_metadata.to_h['thumbnail_url']
      }.compact
    end

    def action_post
      return if action_post_key.blank?

      self.class.find_by(locale: locale, key: action_post_key)
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
      return unless action_url.present? && action_post_key.present?

      errors.add(:base, 'Primary action can open a URL or another post, not both')
    end

    def action_post_is_linkable
      return if action_post_key.blank?

      unless action_post_key.match?(KEY_FORMAT)
        errors.add(:action_post_key, 'must use a valid post key')
        return
      end
      if action_post_key == key
        errors.add(:action_post_key, 'cannot link to the same post')
        return
      end
      return if locale.blank? || self.class.exists?(locale: locale, key: action_post_key)

      errors.add(:action_post_key, 'must identify an existing post in the same locale')
    end

    def uploaded_file_is_video
      return unless uploaded_video?
      return if video.blob.content_type.to_s.start_with?('video/')

      errors.add(:video, 'must be a video file')
    end
  end
end
