# frozen_string_literal: true

module ProductTours
  module Seeds
    DEMO_LOCALES = %w[en fr bg].freeze

    POSTS = [
      {
        key: 'demo_youtube',
        title: 'YouTube tutorial',
        video_url: 'https://www.youtube.com/watch?v=M7lc1UVf-VE'
      },
      {
        key: 'demo_vimeo',
        title: 'Vimeo tutorial',
        video_url: 'https://vimeo.com/76979871'
      },
      {
        key: 'demo_loom',
        title: 'Loom tutorial',
        video_url: 'https://www.loom.com/share/e5b8c04bca094dd8a5507925ab887002'
      },
      {
        key: 'demo_tella',
        title: 'Tella tutorial',
        video_url: 'https://www.tella.tv/video/add-your-logo-to-videos-39y0'
      },
      {
        key: 'demo_voomly',
        title: 'Voomly tutorial',
        video_url: 'https://share.voomly.com/v/CxfDyNYKE0SBEBV-zVAUHo8rNwS2eLBr418z81gd6GlkKlLfJ'
      },
      {
        key: 'demo_direct_video',
        title: 'Direct MP4 tutorial',
        video_url: 'https://interactive-examples.mdn.mozilla.net/media/cc0-videos/flower.mp4'
      },
      {
        key: 'demo_getting_started',
        title: 'Getting started',
        action_label: 'Open settings',
        action_url: '/settings'
      }
    ].freeze

    TRANSLATIONS = {
      'fr' => {
        'demo_youtube' => { title: 'Tutoriel YouTube' },
        'demo_vimeo' => { title: 'Tutoriel Vimeo' },
        'demo_loom' => { title: 'Tutoriel Loom' },
        'demo_tella' => { title: 'Tutoriel Tella' },
        'demo_voomly' => { title: 'Tutoriel Voomly' },
        'demo_direct_video' => { title: 'Tutoriel vidéo MP4' },
        'demo_getting_started' => { title: 'Bien démarrer', action_label: 'Ouvrir les paramètres' }
      },
      'bg' => {
        'demo_youtube' => { title: 'Видео урок в YouTube' },
        'demo_vimeo' => { title: 'Видео урок във Vimeo' },
        'demo_loom' => { title: 'Видео урок в Loom' },
        'demo_tella' => { title: 'Видео урок в Tella' },
        'demo_voomly' => { title: 'Видео урок във Voomly' },
        'demo_direct_video' => { title: 'MP4 видео урок' },
        'demo_getting_started' => { title: 'Първи стъпки', action_label: 'Отвори настройките' }
      }
    }.freeze

    def self.load!(locale: I18n.default_locale, status: 'published')
      POSTS.map do |attributes|
        locale = locale.to_s
        key = attributes.fetch(:key)
        localized = TRANSLATIONS.fetch(locale, {}).fetch(key, {})
        post = ProductTours::Post.find_or_initialize_by(locale: locale, key: key)
        post.assign_attributes(attributes.merge(localized).merge(status: status))
        post.save!
        post
      end
    end

    def self.load_all!(locales: DEMO_LOCALES, status: 'published')
      locales.flat_map { |locale| load!(locale: locale, status: status) }
    end
  end
end
