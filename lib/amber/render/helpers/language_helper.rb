module Amber
  module Render
    module LanguageHelper

      def t(*args)
        I18n.t(*args)
      end

      def translation_missing?
        !@page.content_file_exists?(I18n.locale)
      end

      # return array of arrays, each array with: language_name, language_code, current_url_with_locale_switch
      #
      # [ ['English', :en, 'en/about-us'] ]
      #
      def available_languages
        @site.locales.collect { |locale|
          [Amber::POSSIBLE_LANGUAGES[locale][0], locale, "/"+([locale]+current_page_path).join('/')]
        }
      end

    end
  end
end