# encoding: utf-8

require 'i18n'
require 'i18n/backend/fallbacks'

I18n::Backend::Simple.send(:include, I18n::Backend::Fallbacks)
I18n.enforce_available_locales = false

I18n.load_path += Dir[File.join(File.expand_path('../../../locales', __FILE__), '/**/*.{yml,yaml}')]

module Amber

  #
  # Languages that might possibly be supported.
  #
  # https://en.wikipedia.org/wiki/List_of_languages_by_number_of_native_speakers
  #
  POSSIBLE_LANGUAGES = {
    :zh => ['中文',       'zh', 1, false],   # Chinese
    :es => ['Español',   'es', 2, false],
    :en => ['English',   'en', 3, false],
    :hi => ['Hindi',     'hi', 4, false],
    :ar => ['العربية',   'ar', 5, true],    # Arabic
    :pt => ['Português', 'pt', 6, false],
    :ru => ['Pyccĸий',   'ru', 7, false],   # Russian
    :ja => ['日本語',     'ja', 8, false],   # Japanese
    :pa => ['ਪੰਜਾਬੀ',  'pa', 9, false],   # Punjabi
    :de => ['Deutsch',   'de', 10, false],
    :vi => ['Tiếng Việt','vi', 11, false],  # Vietnamese
    :fr => ['Français',  'fr', 12, false],
    :ur => ['اُردُو',    'ur', 13, false],  # Urdu
    :fa => ['فارسی',     'fa', 14, false],  # Farsi / Persian
    :tr => ['Türkçe',    'tr', 15, false],  # Turkish
    :it => ['Italiano',  'it', 16, false],
    :el => ['Ελληνικά',  'el', 17, false],  # Greek
    :pl => ['Polski',    'pl', 18, false],  # Polish
    :ca => ['Català',    'ca', 19, false]
  }

  # Although everywhere else we use symbols for locales, this array should be strings:
  POSSIBLE_LANGUAGE_CODES = POSSIBLE_LANGUAGES.keys.map(&:to_s)

end
