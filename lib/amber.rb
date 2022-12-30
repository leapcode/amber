# encoding: utf-8

require 'logger'

# ensure that we load sass from a gem, not the sass included in some
# versions of haml.
gem 'sass'
require 'sass'
require 'haml'

module Amber

  class MissingTemplate < StandardError
  end

  # Possible page suffixes. Only files with these suffixes are treated as pages
  PAGE_SUFFIXES = %w(haml md markdown text textile rst html html.haml)

  # Possible variable file suffixes. Only files with these suffixesare treated
  # as variable files.
  VAR_SUFFIXES = %w(json yaml yml)

  DEFAULT_HOST = '127.0.0.1'
  DEFAULT_PORT = '8000'

  def self.env
    if defined?(TESTING) && TESTING==true
      :test
    elsif defined?(Amber::Server)
      :developmet
    else
      :production
    end
  end

end

require 'amber/version'
require 'amber/cli'
require 'amber/logger'
require 'amber/i18n'

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
require 'amber/render/table_of_contents'
require 'amber/render/apache'
require 'amber/render/filter/autolink'
require 'amber/render/filter/bracketlink'
require 'amber/render/filter/variables'
require 'amber/render/sass_helper'
