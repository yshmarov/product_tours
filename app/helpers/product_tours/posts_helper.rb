# frozen_string_literal: true

module ProductTours
  module PostsHelper
    LOCALE_NAMES = {
      'ar' => 'Arabic', 'bg' => 'Bulgarian', 'bn' => 'Bengali', 'de' => 'German', 'el' => 'Greek',
      'en' => 'English', 'es' => 'Spanish', 'fr' => 'French', 'hi' => 'Hindi', 'hr' => 'Croatian',
      'id' => 'Indonesian', 'it' => 'Italian', 'ja' => 'Japanese', 'ko' => 'Korean',
      'lb' => 'Luxembourgish', 'nl' => 'Dutch', 'pl' => 'Polish', 'pt' => 'Portuguese',
      'ro' => 'Romanian', 'ru' => 'Russian', 'th' => 'Thai', 'tr' => 'Turkish', 'uk' => 'Ukrainian',
      'ur' => 'Urdu', 'vi' => 'Vietnamese', 'zh-CN' => 'Chinese (Simplified)'
    }.freeze

    def product_tours_locale_name(locale)
      code = locale.to_s
      "#{LOCALE_NAMES.fetch(code, code.upcase)} (#{code})"
    end
  end
end
