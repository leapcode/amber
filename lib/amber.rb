# encoding: utf-8

require 'logger'
require 'i18n'
require 'i18n/backend/fallbacks'
I18n::Backend::Simple.send(:include, I18n::Backend::Fallbacks)

require 'sass'  # sass seems to freak out if require'd after haml.
require 'haml'  #

module Amber

  class MissingTemplate < StandardError
  end

  #
  # Languages that might possibly be supported.
  #
  # https://en.wikipedia.org/wiki/List_of_languages_by_number_of_native_speakers
  #
  POSSIBLE_LANGUAGES = {
    :zh => ['中文',       'zh', 1, false],
    :es => ['Español',   'es', 2, false],
    :en => ['English',   'en', 3, false],
    :hi => ['Hindi',     'hi', 4, false],
    :ar => ['العربية',   'ar', 5, true],
    :pt => ['Português', 'pt', 6, false],
    :ru => ['Pyccĸий',   'ru', 7, false],
    :de => ['Deutsch',   'de', 8, false],
    :fr => ['Français',  'fr', 10, false],
    :it => ['Italiano',  'it', 11, false],
    :el => ['Ελληνικά',  'el', 20, false],
    :ca => ['Català',    'ca', 101, false]
  }

  # Although everywhere else we use symbols for locales, this array should be strings:
  POSSIBLE_LANGUAGE_CODES = POSSIBLE_LANGUAGES.keys.map(&:to_s)

  # Possible page suffixes. Only files with these suffixes are treated as pages
  PAGE_SUFFIXES = %w(haml md markdown text textile rst html)

  def self.logger
    @logger ||= begin
      logger = Logger.new(STDOUT)
      logger.level = Logger::INFO
      logger.formatter = proc do |severity, datetime, progname, msg|
        "#{severity}: #{msg}\n"
      end
      logger
    end
  end

  def self.env
    if defined?(TESTING) && TESTING==true
      :test
    else
      :production
    end
  end

end

require 'amber/version'
require 'amber/cli'
require 'amber/server'
require 'amber/logger'

require 'amber/menu'
require 'amber/site'
require 'amber/site_configuration'

require 'amber/static_page'
require 'amber/static_page/filesystem'
require 'amber/static_page/render'
require 'amber/static_page/property_set'
require 'amber/static_page/page_properties'
require 'amber/page_array'

require 'amber/render/layout'
require 'amber/render/view'
require 'amber/render/template'
require 'amber/render/asset'
require 'amber/render/autolink'
require 'amber/render/bracketlink'
require 'amber/render/table_of_contents'
require 'amber/render/apache'
