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
      #   :page    -- page path or page object to render
      #   :file    -- renders the file specified, using suffix to determine type.
      #   :partial -- same as :file, but disables layout
      #   :text    -- string to render
      #   :type    -- required for :text
      #
      def render(options={}, locals={}, toc_only=false, &block)
        push_context @locals, @page
        @locals    = @locals.merge(locals)
        locale     = I18n.locale = @locals[:locale]
        options    = parse_render_options(locale, options)
        @page      = options[:page] if options[:page]
        render_toc = should_render_toc?(locale, options, @page)
        template   = pick_template(locale, options)
        if toc_only
          template.render(self, :mode => :toc, :href_base => options[:href_base])
        else
          layout = pick_layout(locale, options)
          if layout
            layout.render(self) do |layout_yield_argument|
              template.render(self, :mode => layout_yield_argument, :toc => render_toc)
            end
          else
            template.render(self, :mode => :content, :toc => render_toc)
          end
        end
      rescue StandardError => exc
        if @site.continue_on_error
          report_error(exc, options)
        else
          raise exc
        end
      ensure
        @locals, @page = pop_context
        I18n.locale = @locals[:locale]
      end

      def render_toc(options={}, locals={})
        render(options, locals, true)
      end

      private

      def find_file(path, site, page, locale)
        search = [
          path,
          "#{site.pages_dir}/#{path}",
          "#{page.file_path}/#{path}",
          "#{File.dirname(page.file_path)}/#{path}",
          "#{site.config_dir}/#{path}"
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

      def push_context(locals, page)
        @stack.push([locals, page])
      end

      def pop_context
        @stack.pop
      end

      #
      # cleans up the `options` arg that is passed to render()
      #
      def parse_render_options(locale, options)
        # handle non-hash options
        if options.is_a?(String)
          page = @site.find_page(options)
          if page
            options = {:page => page}
          else
            options = {:partial => options}
          end
        elsif options.is_a?(StaticPage)
          options = {:page => options}
        end

        # convert :page, :partial, or :file to the real deal
        if options[:page]
          if options[:page].is_a?(String)
            options[:page] = @site.find_page(options[:page])
          end
          options[:href_base] ||= amber_path(options[:page], locale)
        elsif options[:partial]
          options[:partial] = find_file(partialize(options[:partial]), @site, @page, locale)
        elsif options[:file]
          options[:file] = find_file(options[:file], @site, @page, locale)
        end
        return options
      end

      def should_render_toc?(locale, options, page)
        if options[:partial].nil?
          if page.prop(locale, :toc).nil?
            true
          else
            page.prop(locale, :toc)
          end
        else
          false
        end
      end

      def pick_template(locale, options)
        if options[:page]
          Template.new(file: options[:page].content_file(locale))
        elsif options[:file]
          Template.new(file: options[:file])
        elsif options[:partial]
          Template.new(file: options[:partial], partial: true)
        elsif options[:text]
          Template.new(content: options[:text], type: (options[:type] || :text))
        end
      end

      def pick_layout(locale, options)
        if options[:layout] && !options[:partial]
          Render::Layout[options[:layout]]
        else
          nil
        end
      end

      def report_error(exc, options)
        if exc.is_a? MissingTemplate
          msg = "ERROR: render() could not find file from #{options.inspect}"
          Amber.logger.error(msg)
          Amber.log_exception(exc)
          "<pre>%s</pre>" % [msg, exc, exc.backtrace].flatten.join("\n")
        else
          Amber.log_exception(exc)
          "<pre>%s</pre>" % [exc, exc.backtrace].flatten.join("\n")
        end
      end
    end
  end
end
