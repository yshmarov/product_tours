# frozen_string_literal: true

module ProductTours
  class ToursController < DashboardController
    PER_PAGE = 50

    before_action :set_tour,
                  only: %i[show edit update destroy refresh_video_metadata add_translation publish unpublish]
    before_action :load_linkable_tours, only: %i[new create edit update]
    before_action :load_translations, only: :show

    def index
      @status = Tour::STATUSES.include?(params[:status]) ? params[:status] : 'published'
      @query = params[:q].to_s.strip.presence
      @counts = Tour.where(locale: default_locale).group(:status).count

      key_scope = Tour.where(status: @status, locale: default_locale)
      @keys = key_scope.distinct.order(:key).pluck(:key)

      scope = tours_with_video.newest_first.where(status: @status, locale: default_locale)
      scope = scope.where('LOWER(key) LIKE ?', "%#{Tour.sanitize_sql_like(@query.downcase)}%") if @query
      @page = [params[:page].to_i, 1].max
      @tours = scope.offset((@page - 1) * PER_PAGE).limit(PER_PAGE + 1).to_a
      @more = @tours.size > PER_PAGE
      @tours = @tours.first(PER_PAGE)

      @selected_tour = tours_with_video.find_by(id: params[:tour_id]) if params[:tour_id].present?
      load_translations if @selected_tour
    end

    def show; end

    def new
      @tour = Tour.new(locale: default_locale)
    end

    def create
      @tour = Tour.new(tour_attributes.merge(locale: default_locale))
      if @tour.save
        redirect_to tour_path(@tour), notice: t('product_tours.dashboard.created', default: 'Tutorial created.')
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @tour.update(tour_attributes)
        remove_uploaded_video if remove_uploaded_video?
        redirect_to tour_path(@tour), notice: t('product_tours.dashboard.updated', default: 'Tutorial updated.')
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if default_locale_tour?(@tour) && translations_for(@tour).where.not(id: @tour.id).exists?
        redirect_to tour_path(@tour),
                    alert: t('product_tours.dashboard.delete_translations_first',
                             default: 'Delete this tutorial\'s translations before deleting the ' \
                                      'default-language tutorial.')
        return
      end

      @tour.destroy!
      redirect_to tours_path,
                  notice: t('product_tours.dashboard.deleted', default: 'Tutorial deleted.'), status: :see_other
    end

    def add_translation
      locale = params[:locale].to_s
      unless available_locales.include?(locale) && locale != @tour.locale
        redirect_to tour_path(@tour),
                    alert: t('product_tours.dashboard.translation_locale_invalid',
                             default: 'Choose another available language.')
        return
      end

      existing = Tour.find_by(locale: locale, key: @tour.key)
      if existing
        redirect_to tour_path(existing),
                    notice: t('product_tours.dashboard.translation_exists',
                              default: 'That translation already exists.')
        return
      end

      source = translations_for(@tour).find_by(locale: default_locale) || @tour
      translation = source.dup
      translation.locale = locale
      translation.status = 'draft'
      translation.captions_url = nil if Tour.captions_supported?
      if translation.action_tour_key.present? &&
         !Tour.exists?(locale: locale, key: translation.action_tour_key)
        translation.action_tour_key = nil
      end
      translation.save!
      if Tour.description_supported? && source.description.present?
        translation.update!(description: source.description.body)
      end
      translation.video.attach(source.video.blob) if source.uploaded_video?

      redirect_to edit_tour_path(translation),
                  notice: t('product_tours.dashboard.translation_added',
                            default: 'Translation added as a draft. Translate its content before publishing.')
    end

    def publish
      @tour.update!(status: 'published')
      redirect_to tour_path(@tour), notice: t('product_tours.dashboard.published', default: 'Tutorial published.')
    end

    def unpublish
      @tour.update!(status: 'draft')
      redirect_to tour_path(@tour),
                  notice: t('product_tours.dashboard.unpublished', default: 'Tutorial moved to drafts.')
    end

    def video_preview
      resolved = VideoResolver.resolve(params[:url])
      unless resolved
        render json: { error: t('product_tours.dashboard.video_invalid', default: 'Enter a supported video URL.') },
               status: :unprocessable_entity
        return
      end

      metadata = VideoMetadata.fetch(params[:url])
      render json: {
        kind: resolved.kind,
        provider: resolved.provider,
        url: resolved.url,
        title: metadata['provider_title'],
        thumbnail_url: metadata['thumbnail_url']
      }.compact
    end

    def refresh_video_metadata
      metadata = VideoMetadata.fetch(@tour.video_url)
      if metadata.present?
        @tour.update!(video_metadata: @tour.video_metadata.to_h.merge(metadata))
        redirect_to edit_tour_path(@tour),
                    notice: t('product_tours.dashboard.metadata_updated', default: 'Video data refreshed.')
      else
        redirect_to edit_tour_path(@tour),
                    alert: t('product_tours.dashboard.metadata_failed',
                             default: 'Video data could not be fetched. The URL was not changed.')
      end
    end

    private

    def tours_with_video
      Tour.video_upload_supported? ? Tour.with_attached_video : Tour.all
    end

    def set_tour
      @tour = Tour.find(params[:id])
    end

    def tour_params
      permitted = %i[key status title video_url action_label action_url action_tour_key]
      permitted << :description if Tour.description_supported?
      permitted << :video if Tour.video_upload_supported?
      permitted << :poster_url if Tour.poster_supported?
      permitted << :captions_url if Tour.captions_supported?
      params.require(:tour).permit(*permitted)
    end

    def tour_attributes
      attributes = tour_params
      attributes.delete(:key) if identity_locked?
      case params[:video_source]
      when 'url'
        attributes.delete(:video)
      when 'upload'
        attributes[:video_url] = nil
      end
      case params[:action_target]
      when 'close'
        attributes[:action_url] = nil
        attributes[:action_tour_key] = nil
      when 'url'
        attributes[:action_tour_key] = nil
      when 'tour'
        attributes[:action_url] = nil
      end
      attributes
    end

    def load_linkable_tours
      @linkable_tours = Tour.where.not(id: @tour&.id).order(:locale, :title, :key)
                            .select(:id, :key, :locale, :status, :title)
      @identity_locked = identity_locked?
    end

    def load_translations
      tour = @selected_tour || @tour
      @translations = translations_for(tour).order(:locale).to_a
      @missing_translation_locales = available_locales - @translations.map(&:locale)
    end

    def translations_for(tour)
      Tour.where(key: tour.key)
    end

    def available_locales
      (I18n.available_locales.map(&:to_s) + [default_locale]).uniq.sort
    end

    def default_locale
      I18n.default_locale.to_s
    end

    def default_locale_tour?(tour)
      tour.locale == default_locale
    end

    def identity_locked?
      @tour&.persisted? &&
        (!default_locale_tour?(@tour) || translations_for(@tour).where.not(id: @tour.id).exists?)
    end

    def remove_uploaded_video?
      params[:video_source] == 'url' && @tour.uploaded_video?
    end

    def remove_uploaded_video
      @tour.video.purge if @tour.uploaded_video?
    end
  end
end
