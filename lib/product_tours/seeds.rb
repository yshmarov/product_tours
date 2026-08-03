# frozen_string_literal: true

module ProductTours
  module Seeds
    DEMO_LOCALES = %w[en fr bg].freeze

    POSTS = [
      {
        key: 'demo_walkthrough_finish',
        title: 'You are ready',
        action_label: 'Get started'
      },
      {
        key: 'demo_direct_video',
        title: 'Direct MP4 tutorial',
        video_url: 'https://interactive-examples.mdn.mozilla.net/media/cc0-videos/flower.mp4',
        action_post_key: 'demo_walkthrough_finish'
      },
      {
        key: 'demo_voomly',
        title: 'Voomly tutorial',
        video_url: 'https://share.voomly.com/v/CxfDyNYKE0SBEBV-zVAUHo8rNwS2eLBr418z81gd6GlkKlLfJ',
        action_post_key: 'demo_direct_video'
      },
      {
        key: 'demo_tella',
        title: 'Tella tutorial',
        video_url: 'https://www.tella.tv/video/add-your-logo-to-videos-39y0',
        action_post_key: 'demo_voomly'
      },
      {
        key: 'demo_loom',
        title: 'Loom tutorial',
        video_url: 'https://www.loom.com/share/e5b8c04bca094dd8a5507925ab887002',
        action_post_key: 'demo_tella'
      },
      {
        key: 'demo_vimeo',
        title: 'Vimeo tutorial',
        video_url: 'https://vimeo.com/76979871',
        action_post_key: 'demo_loom'
      },
      {
        key: 'demo_youtube',
        title: 'YouTube tutorial',
        video_url: 'https://www.youtube.com/watch?v=M7lc1UVf-VE',
        action_post_key: 'demo_vimeo'
      },
      {
        key: 'demo_walkthrough_features',
        title: 'Compare every supported video provider',
        action_post_key: 'demo_youtube'
      },
      {
        key: 'demo_walkthrough_start',
        title: 'Video provider walkthrough',
        action_post_key: 'demo_walkthrough_features'
      },
      {
        key: 'demo_getting_started',
        title: 'Getting started',
        action_label: 'Open settings',
        action_url: '/settings'
      },
      {
        key: 'demo_draft',
        title: 'Draft tutorial',
        status: 'draft'
      }
    ].freeze

    BUTTONS = [
      ['demo_walkthrough_start', 'Try the multi-step walkthrough'],
      ['demo_youtube', 'Open the YouTube tutorial'],
      ['demo_vimeo', 'Open the Vimeo tutorial'],
      ['demo_loom', 'Open the Loom tutorial'],
      ['demo_tella', 'Open the Tella tutorial'],
      ['demo_voomly', 'Open the Voomly tutorial'],
      ['demo_direct_video', 'Open the direct video tutorial'],
      ['demo_getting_started', 'Open the getting started guide'],
      ['demo_draft', 'Try an unpublished tutorial'],
      ['demo_missing_post', 'Try a missing tutorial']
    ].freeze

    TRANSLATIONS = {
      'fr' => {
        'demo_walkthrough_finish' => { title: 'Vous êtes prêt', action_label: 'Commencer' },
        'demo_walkthrough_features' => { title: 'Comparez tous les fournisseurs vidéo pris en charge' },
        'demo_walkthrough_start' => { title: 'Présentation des fournisseurs vidéo' },
        'demo_youtube' => { title: 'Tutoriel YouTube' },
        'demo_vimeo' => { title: 'Tutoriel Vimeo' },
        'demo_loom' => { title: 'Tutoriel Loom' },
        'demo_tella' => { title: 'Tutoriel Tella' },
        'demo_voomly' => { title: 'Tutoriel Voomly' },
        'demo_direct_video' => { title: 'Tutoriel vidéo MP4' },
        'demo_getting_started' => { title: 'Bien démarrer', action_label: 'Ouvrir les paramètres' },
        'demo_draft' => { title: 'Tutoriel brouillon' }
      },
      'bg' => {
        'demo_walkthrough_finish' => { title: 'Готови сте', action_label: 'Започнете' },
        'demo_walkthrough_features' => { title: 'Сравнете всички поддържани видео доставчици' },
        'demo_walkthrough_start' => { title: 'Обиколка на видео доставчиците' },
        'demo_youtube' => { title: 'Видео урок в YouTube' },
        'demo_vimeo' => { title: 'Видео урок във Vimeo' },
        'demo_loom' => { title: 'Видео урок в Loom' },
        'demo_tella' => { title: 'Видео урок в Tella' },
        'demo_voomly' => { title: 'Видео урок във Voomly' },
        'demo_direct_video' => { title: 'MP4 видео урок' },
        'demo_getting_started' => { title: 'Първи стъпки', action_label: 'Отвори настройките' },
        'demo_draft' => { title: 'Чернова на урок' }
      }
    }.freeze

    def self.load!(locale: I18n.default_locale, status: 'published')
      POSTS.map do |attributes|
        locale = locale.to_s
        key = attributes.fetch(:key)
        localized = TRANSLATIONS.fetch(locale, {}).fetch(key, {})
        post = ProductTours::Post.find_or_initialize_by(locale: locale, key: key)
        post.assign_attributes(attributes.merge(localized).merge(status: attributes.fetch(:status, status)))
        post.save!
        post
      end
    end

    def self.load_all!(locales: DEMO_LOCALES, status: 'published')
      locales.flat_map { |locale| load!(locale: locale, status: status) }
    end

    def self.load_for_install!(environment: defined?(Rails) && Rails.env)
      return [] unless environment&.development?

      ProductTours::Post.reset_column_information
      load!
    end

    def self.trigger_html
      lines = ['<div class="product-tours-demo">']
      BUTTONS.each do |key, label|
        lines << %(  <button type="button" data-product-tour="#{key}">#{label}</button>)
      end
      lines << '</div>'
      lines << '<%= product_tours_tag %>'
      lines.join("\n")
    end
  end
end
