#
# All pages and layouts are evaluated in the context of a View object.
#
# Any methods you want to make available to these templates should be added to this class.
#

require 'i18n'
require 'amber/render/helpers/html_helper'
require 'amber/render/helpers/navigation_helper'
require 'amber/render/helpers/haml_helper'
require 'amber/render/helpers/language_helper'

module Amber
  module Render
    class View
      attr_reader :locals
      attr_reader :page
      attr_reader :site

      # include helpers (get added as member functions)
      include HtmlHelper
      include NavigationHelper
      include HamlHelper
      include LanguageHelper

      def initialize(page, site)
        @page = page
        @site = site
        @stack = []
        @locals = {}
        @this = StaticPage::PropertySet.new # TODO: come up with a better way to handle this.
                                            # @this is not actually used, it is just there so haml headers don't bomb out.
      end

      #
      # more or less the same as Rails render()
      #
      # supported options:
      #   :file    -- renders the file specified, using suffix to determine type.
      #   :partial -- same as :file, but disables layout
      #   :text -- string to render
      #   :type -- required for :text
      #
      def render(options={}, locals={}, &block)
        push_locals(locals)
        locale = I18n.locale
        if options.is_a? String
          options = {:partial => options}
        end
        if options[:partial]
          template = Template.new(file: find_file(partialize(options[:partial]), locale), partial: true)
        elsif options[:file]
          template = Template.new(file: find_file(options[:file], locale))
        elsif options[:text]
          template = Template.new(content: options[:text], type: options[:type])
        end
        if options[:layout] && !options[:partial]
          layout = Render::Layout[options[:layout]]
          layout.render(self) { |layout_yield_argument| template.render(self, layout_yield_argument) }
        else
          template.render(self)
        end
      rescue MissingTemplate
        "ERROR: render() could not find file from #{options.inspect}".tap {|msg|
          Amber.logger.error(msg)
          return msg
        }
      rescue Exception => exc
        Amber.log_exception(exc)
      ensure
        pop_locals
      end

      def render_toc(page, options={})
        unless page.is_a?(StaticPage)
          page = @site.find_pages(page)
        end
        if page
          locale = @locals[:locale]
          file   = page.content_file(locale)
          template = Template.new(file: file)
          options[:href_base] ||= page_path(page, locale)
          template.render_toc(self, options)
        else
          ""
        end
      end

      private

      def find_file(path, locale)
        search = [
          path,
          "#{@site.pages_dir}/#{path}",
          "#{@page.file_path}/#{path}",
          "#{File.dirname(@page.file_path)}/#{path}",
          "#{@site.config_dir}/#{path}"
        ]
        search.each do |path|
          return path if File.exists?(path)
          Dir["#{path}.#{locale}.*"].each do |path_with_locale|
            return path_with_locale if File.exists?(path_with_locale)
          end
          Dir["#{path}.*"].each do |path_with_suffix|
            return path_with_suffix if File.exists?(path_with_suffix)
          end
        end
        raise MissingTemplate.new(path)
      end

      def partialize(path)
        File.dirname(path) + "/_" + File.basename(path)
      end

      def push_locals(locals)
        @stack.push(@locals)
        @locals = @locals.merge(locals)
        I18n.locale = @locals[:locale]
      end

      def pop_locals
        @locals = @stack.pop
        I18n.locale = @locals[:locale]
      end

    end
  end
end
