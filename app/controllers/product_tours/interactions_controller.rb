# frozen_string_literal: true

module ProductTours
  class InteractionsController < ApplicationController
    SIGNALS = %w[viewed dismissed completed].freeze

    def resolve
      key = params[:key].to_s
      return handle_unresolved_trigger(key, :disabled) unless ProductTours.enabled?(request)
      return handle_unresolved_trigger(key, :invalid_key) unless key.match?(Tour::KEY_FORMAT)

      tour = find_tour_by_locale(Tour.all, key)
      return handle_unresolved_trigger(key, :missing) unless tour
      return handle_unresolved_trigger(key, :unpublished) unless tour.published?

      render json: tour_payload(tour)
    end

    def signal
      return head :forbidden unless ProductTours.enabled?(request)

      action = params[:event_action].to_s
      return head :unprocessable_entity unless SIGNALS.include?(action)

      tour = find_tour_by_locale(Tour.published, params[:key].to_s)
      return head :not_found unless tour

      payload = {
        tour_id: tour.id,
        key: tour.key,
        locale: tour.locale,
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

    def tour_payload(tour)
      video = player_video(tour)
      {
        key: tour.key,
        locale: tour.locale,
        title: tour.title,
        descriptionHtml: description_html(tour),
        video: video,
        action: {
          label: tour.action_label.presence || default_action_label(tour),
          url: tour.action_url.presence,
          tourKey: tour.action_tour_key.presence
        }
      }
    end

    def player_video(tour)
      video = tour.resolved_video
      return if video.nil?

      video[:url] = media_path(tour) if video[:kind] == 'upload'
      video[:poster] = video.delete(:poster_url)
      if (captions_url = video.delete(:captions_url))
        video[:captions] = { url: captions_url, srclang: tour.locale, label: captions_label(tour.locale) }
      end
      video.compact
    end

    # Named in its own language, as a player's captions menu lists them.
    def captions_label(locale)
      I18n.t(:captions_label, scope: :product_tours, locale: locale, default: locale.to_s)
    rescue I18n::InvalidLocale
      locale.to_s
    end

    def default_action_label(tour)
      key = tour.action_tour_key.present? ? :next : :done
      I18n.t(key, scope: :product_tours, default: key.to_s.humanize)
    end

    def description_html(tour)
      return unless Tour.description_supported? && tour.description.present?

      tour.description.body.to_s
    end
  end
end
