# frozen_string_literal: true

module ProductTours
  module Seeds
    DEMO_LOCALES = %w[en fr bg].freeze

    POSTS = [
      {
        key: 'demo_walkthrough_finish',
        title: 'You completed the Product Tours tour',
        description: '<p>Completing this step emits <code>product_tours.completed</code>. ' \
                     'Replace these demo posts with one short guide tied to a real customer success moment.</p>',
        action_label: 'Finish tour'
      },
      {
        key: 'demo_direct_video',
        title: 'Keep video delivery flexible',
        description: '<p>This placeholder uses a direct MP4. You can also attach a video with Active Storage; ' \
                     'uploaded media streams through the engine rather than a public blob URL.</p>',
        video_url: 'https://interactive-examples.mdn.mozilla.net/media/cc0-videos/flower.mp4',
        action_post_key: 'demo_walkthrough_finish'
      },
      {
        key: 'demo_voomly',
        title: 'Observe the lifecycle',
        description: '<p>Subscribe to viewed, dismissed, completed, and unresolved-trigger notifications, ' \
                     'or use <code>config.on_event</code> when you need the raw request to resolve a user.</p>',
        video_url: 'https://share.voomly.com/v/CxfDyNYKE0SBEBV-zVAUHo8rNwS2eLBr418z81gd6GlkKlLfJ',
        action_post_key: 'demo_direct_video'
      },
      {
        key: 'demo_tella',
        title: 'Translate one stable key',
        description: '<p>A tutorial keeps the same key in every locale. Product Tours resolves the visitor locale ' \
                     'and falls back to your default locale, so triggers never need translated keys.</p>',
        video_url: 'https://www.tella.tv/video/add-your-logo-to-videos-39y0',
        action_post_key: 'demo_voomly'
      },
      {
        key: 'demo_loom',
        title: 'Draft safely, then publish',
        description: '<p>The seeded <code>demo_draft</code> post appears in the dashboard but cannot open for ' \
                     'visitors. Use drafts to review copy, actions, and video before a trigger goes live.</p>',
        video_url: 'https://www.loom.com/share/e5b8c04bca094dd8a5507925ab887002',
        action_post_key: 'demo_tella'
      },
      {
        key: 'demo_vimeo',
        title: 'Chain focused steps',
        description: '<p>This Next button follows <code>action_post_key</code>. Each step is an ordinary tutorial, ' \
                     'so you can reuse it alone or connect it into a walkthrough without host-side JavaScript.</p>',
        video_url: 'https://vimeo.com/76979871',
        action_post_key: 'demo_loom'
      },
      {
        key: 'demo_youtube',
        title: 'Add video only when it helps',
        description: '<p>This generic YouTube clip is only a provider example. Replace it with your own explanation, ' \
                     'or leave video blank for a fast text-only guide.</p>',
        video_url: 'https://www.youtube.com/watch?v=M7lc1UVf-VE',
        action_post_key: 'demo_vimeo'
      },
      {
        key: 'demo_walkthrough_features',
        title: 'Trigger a tour from your own UI',
        description: '<p>Add <code>data-product-tour="demo_walkthrough_start"</code> to any button or link. ' \
                     'The single <code>product_tours_tag</code> in your layout handles every trigger on the page.</p>',
        action_post_key: 'demo_youtube'
      },
      {
        key: 'demo_walkthrough_start',
        title: 'Welcome to Product Tours',
        description: '<p>This is a real multi-step tour created by <code>product_tours:seed_demo</code>. ' \
                     'Continue to learn the public API by using the same experience your customers will see.</p>',
        action_post_key: 'demo_walkthrough_features'
      },
      {
        key: 'demo_getting_started',
        title: 'Link to the next real action',
        description: '<p>An action URL completes the tutorial and sends the visitor into your product. ' \
                     'Point it at the screen where they can immediately use what the guide taught.</p>',
        action_label: 'Try the action URL',
        action_url: '/settings'
      },
      {
        key: 'demo_draft',
        title: 'This draft stays invisible to visitors',
        description: '<p>You can edit and preview this post in the dashboard, but its demo trigger will not resolve ' \
                     'until you publish it.</p>',
        status: 'draft'
      }
    ].freeze

    BUTTONS = [
      ['demo_walkthrough_start', 'Take the self-guided Product Tours tour'],
      ['demo_youtube', 'Preview a YouTube video step'],
      ['demo_vimeo', 'Preview a Vimeo video step'],
      ['demo_loom', 'Preview a Loom video step'],
      ['demo_tella', 'Preview a Tella video step'],
      ['demo_voomly', 'Preview a Voomly video step'],
      ['demo_direct_video', 'Preview a direct MP4 step'],
      ['demo_getting_started', 'Try a tour that opens a product page'],
      ['demo_draft', 'Confirm that draft tours stay hidden'],
      ['demo_missing_post', 'Confirm that missing keys are instrumented']
    ].freeze

    TRANSLATIONS = {
      'fr' => {
        'demo_walkthrough_finish' => {
          title: 'Vous avez terminé la visite de Product Tours',
          description: '<p>Cette étape émet <code>product_tours.completed</code>. Remplacez ces exemples par ' \
                       'un guide court lié à un vrai moment de réussite client.</p>',
          action_label: 'Terminer la visite'
        },
        'demo_walkthrough_features' => {
          title: 'Déclenchez une visite depuis votre interface',
          description: '<p>Ajoutez <code>data-product-tour="demo_walkthrough_start"</code> à un bouton ou un lien. ' \
                       '<code>product_tours_tag</code> gère tous les déclencheurs de la page.</p>'
        },
        'demo_walkthrough_start' => {
          title: 'Bienvenue dans Product Tours',
          description: '<p>Ceci est une vraie visite en plusieurs étapes créée par ' \
                       '<code>product_tours:seed_demo</code>. Continuez pour découvrir son API publique.</p>'
        },
        'demo_youtube' => {
          title: 'Ajoutez une vidéo seulement si elle aide',
          description: '<p>Cette vidéo YouTube générique illustre seulement le fournisseur. Remplacez-la par la ' \
                       'vôtre, ou laissez le champ vide pour un guide textuel rapide.</p>'
        },
        'demo_vimeo' => {
          title: 'Enchaînez des étapes ciblées',
          description: '<p>Le bouton Suivant utilise <code>action_post_key</code>. Reliez des guides sans écrire ' \
                       'de JavaScript dans votre application.</p>'
        },
        'demo_loom' => {
          title: 'Préparez en brouillon, puis publiez',
          description: '<p>Le post <code>demo_draft</code> est visible dans le tableau de bord, mais pas pour les ' \
                       'visiteurs. Vérifiez le contenu avant de publier.</p>'
        },
        'demo_tella' => {
          title: 'Traduisez une clé stable',
          description: '<p>Une visite garde la même clé dans chaque langue. Le déclencheur ne doit donc jamais ' \
                       'connaître la clé traduite.</p>'
        },
        'demo_voomly' => {
          title: 'Observez le cycle de vie',
          description: '<p>Abonnez-vous aux événements viewed, dismissed, completed et unresolved-trigger, ' \
                       'ou utilisez <code>config.on_event</code> avec la requête.</p>'
        },
        'demo_direct_video' => {
          title: 'Gardez le choix de la diffusion vidéo',
          description: '<p>Cet exemple utilise un MP4 direct. Active Storage permet aussi les fichiers envoyés, ' \
                       'diffusés par le moteur sans URL de blob publique.</p>'
        },
        'demo_getting_started' => {
          title: "Ouvrez l'action réelle suivante",
          description: '<p>Une URL d’action termine la visite et envoie le visiteur vers la page où il peut ' \
                       'appliquer ce qu’il vient d’apprendre.</p>',
          action_label: "Essayer l'URL d'action"
        },
        'demo_draft' => {
          title: 'Ce brouillon reste invisible aux visiteurs',
          description: '<p>Modifiez-le dans le tableau de bord : son déclencheur ne fonctionnera qu’après sa ' \
                       'publication.</p>'
        }
      },
      'bg' => {
        'demo_walkthrough_finish' => {
          title: 'Завършихте обиколката на Product Tours',
          description: '<p>Тази стъпка излъчва <code>product_tours.completed</code>. Заменете примерите с кратък ' \
                       'урок, свързан с реален успех на клиента.</p>',
          action_label: 'Край на обиколката'
        },
        'demo_walkthrough_features' => {
          title: 'Стартирайте обиколка от вашия интерфейс',
          description: '<p>Добавете <code>data-product-tour="demo_walkthrough_start"</code> към бутон или връзка. ' \
                       '<code>product_tours_tag</code> обслужва всички тригери на страницата.</p>'
        },
        'demo_walkthrough_start' => {
          title: 'Добре дошли в Product Tours',
          description: '<p>Това е истинска обиколка от няколко стъпки, създадена от ' \
                       '<code>product_tours:seed_demo</code>. Продължете, за да научите публичния API.</p>'
        },
        'demo_youtube' => {
          title: 'Добавяйте видео само когато помага',
          description: '<p>Този общ YouTube клип е само пример за доставчик. Заменете го със свой или оставете ' \
                       'полето празно за бърз текстов урок.</p>'
        },
        'demo_vimeo' => {
          title: 'Свържете кратки, фокусирани стъпки',
          description: '<p>Бутонът Напред използва <code>action_post_key</code>. Свързвайте уроци без JavaScript ' \
                       'в приложението домакин.</p>'
        },
        'demo_loom' => {
          title: 'Подгответе чернова, после публикувайте',
          description: '<p>Публикацията <code>demo_draft</code> се вижда в таблото, но не и от посетителите. ' \
                       'Прегледайте съдържанието преди публикуване.</p>'
        },
        'demo_tella' => {
          title: 'Преведете един постоянен ключ',
          description: '<p>Една обиколка използва същия ключ на всеки език. Тригерът никога не се нуждае от ' \
                       'преведен ключ.</p>'
        },
        'demo_voomly' => {
          title: 'Наблюдавайте жизнения цикъл',
          description: '<p>Абонирайте се за viewed, dismissed, completed и unresolved-trigger или използвайте ' \
                       '<code>config.on_event</code> с текущата заявка.</p>'
        },
        'demo_direct_video' => {
          title: 'Изберете как да доставяте видеото',
          description: '<p>Този пример използва директен MP4. Active Storage поддържа и качени файлове, които ' \
                       'се предават през двигателя без публичен blob URL.</p>'
        },
        'demo_getting_started' => {
          title: 'Отворете следващото реално действие',
          description: '<p>URL действието завършва урока и отвежда посетителя до мястото, където може веднага ' \
                       'да използва наученото.</p>',
          action_label: 'Изпробвайте URL действието'
        },
        'demo_draft' => {
          title: 'Тази чернова остава скрита за посетители',
          description: '<p>Редактирайте я в таблото; нейният тригер няма да работи, докато не я ' \
                       'публикувате.</p>'
        }
      }
    }.freeze

    def self.load!(locale: I18n.default_locale, status: 'published')
      POSTS.map do |attributes|
        locale = locale.to_s
        key = attributes.fetch(:key)
        localized = TRANSLATIONS.fetch(locale, {}).fetch(key, {})
        post = ProductTours::Post.find_or_initialize_by(locale: locale, key: key)
        seed_attributes = attributes.merge(localized).merge(status: attributes.fetch(:status, status))
        description = seed_attributes.delete(:description)
        post.assign_attributes(seed_attributes)
        post.description = description if ProductTours::Post.description_supported?
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
