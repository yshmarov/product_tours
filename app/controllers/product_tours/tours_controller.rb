# frozen_string_literal: true

module ProductTours
  class ToursController < ApplicationController
    SIGNALS = %w[viewed dismissed completed].freeze

    def resolve
      key = params[:key].to_s
      return handle_unresolved_trigger(key, :disabled) unless ProductTours.enabled?(request)
      return handle_unresolved_trigger(key, :invalid_key) unless key.match?(Post::KEY_FORMAT)

      post = find_post_by_locale(Post.all, key)
      return handle_unresolved_trigger(key, :missing) unless post
      return handle_unresolved_trigger(key, :unpublished) unless post.published?

      render json: post_payload(post)
    end

    def signal
      return head :forbidden unless ProductTours.enabled?(request)

      action = params[:event_action].to_s
      return head :unprocessable_entity unless SIGNALS.include?(action)

      post = find_post_by_locale(Post.published, params[:key].to_s)
      return head :not_found unless post

      payload = {
        post_id: post.id,
        key: post.key,
        locale: post.locale,
        page_url: clean_page_url(params[:page_url]),
        source: params[:source].to_s.presence
      }
      event_name = "product_tours.#{action}"
      ActiveSupport::Notifications.instrument(event_name, payload)
      notify_host(event_name, payload)
      head :no_content
    end

    private

    def notify_host(event_name, payload)
      ProductTours.config.on_event.call(event_name, payload, request)
    rescue StandardError => e
      Rails.logger.error("product_tours: on_event hook raised #{e.class}: #{e.message}")
    end

    def post_payload(post)
      video = post.resolved_video
      video[:url] = media_path(post) if video&.dig(:kind) == 'upload'
      {
        key: post.key,
        locale: post.locale,
        title: post.title,
        descriptionHtml: description_html(post),
        video: video,
        action: {
          label: post.action_label.presence || default_action_label(post),
          url: post.action_url.presence,
          postKey: post.action_post_key.presence
        }
      }
    end

    def default_action_label(post)
      key = post.action_post_key.present? ? :next : :done
      I18n.t(key, scope: :product_tours, default: key.to_s.humanize)
    end

    def description_html(post)
      return unless Post.description_supported? && post.description.present?

      post.description.body.to_s
    end
  end
end
