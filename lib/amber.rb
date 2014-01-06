# encoding: utf-8

require 'logger'

module Amber

  #
  # Languages that might possibly be supported.
  #
  # https://en.wikipedia.org/wiki/List_of_languages_by_number_of_native_speakers
  #
  POSSIBLE_LANGUAGES = {
    :zh => ['中文',       'zh', 1, false],
    :es => ['Español',   'es', 2, false],
    :en => ['English',   'en', 3, false],
    :ar => ['العربية',   'ar', 5, true],
    :pt => ['Português', 'pt', 6, false],
    :ru => ['Pyccĸий',   'ru', 7, false],
    :de => ['Deutsch',   'de', 8, false],
    :fr => ['Français',  'fr', 10, false],
    :it => ['Italiano',  'it', 11, false],
    :el => ['Ελληνικά',  'el', 20, false]
  }

  # Although everywhere else we use symbols for locales, this array should be strings:
  POSSIBLE_LANGUAGE_CODES = POSSIBLE_LANGUAGES.keys.map(&:to_s)

  def self.logger
    @logger ||= begin
      logger = Logger.new(STDOUT)
      logger.level = Logger::DEBUG
      logger
    end
  end

end

require 'amber/menu'
require 'amber/property_set'
require 'amber/site'
require 'amber/site_configuration'
require 'amber/site_mount_point'
require 'amber/static_page'
require 'amber/static_page_array'
require 'amber/cli'
require 'amber/render/layout'
require 'amber/render/view'