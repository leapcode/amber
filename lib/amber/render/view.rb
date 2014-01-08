#
# All pages and layouts are evaluated in the context of a View object.
#
# Any methods you want to make available to these templates should be added to this class.
#

require 'i18n'

module Amber
  module Render
    class View
      attr_reader :locals
      attr_reader :page
      attr_reader :site

      def initialize(page, site)
        @page = page
        @site = site
        @stack = []
        @locals = {}
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
        locale = @locals[:locale]
        if options[:partial]
          template = Template.new(file: find_file(partialize(options[:partial]), locale))
        elsif options[:file]
          template = Template.new(file: find_file(options[:file], locale))
        elsif options[:text]
          template = Template.new(content: options[:text], type: options[:type])
        end
        if options[:layout] && !options[:partial]
          layout = Render::Layout[options[:layout]]
          layout.render(self, template.render(self))
        elsif @locals[:_type] == template.type
          File.read(template.file) # don't render if the calling template is of the same type.
        else
          template.render(self)
        end
      rescue MissingTemplate
        "ERROR: render() could not find file from #{options.inspect}".tap {|msg|
          Amber.logger.error(msg)
          return msg
        }
      rescue Exception => exc
        Amber.logger.error(exc)
      ensure
        pop_locals
      end

      def t(*args)
        I18n.t(*args)
      end

      private

      def find_file(path, locale)
        search = [path, "#{@site.pages_dir}/#{path}",
                 "#{@page.file_path}/#{path}", "#{File.dirname(@page.file_path)}/#{path}"]
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
      end

      def pop_locals
        @locals = @stack.pop
      end

    end
  end
end
