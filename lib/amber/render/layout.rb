#
# A Layout is similar to a layout in Rails (a template that decorates the pages)
#

gem 'tilt', '>= 2.0.0'
require 'tilt'
require 'haml'

#Haml::Options.defaults[:format] = :html5

module Amber
  module Render

    class Layout
      def self.load(layouts_dir=nil)
        @layouts ||= {}
        @layouts['default'] = DefaultLayout.new
        if layouts_dir
          Dir.glob("#{layouts_dir}/*").each do |layout_file|
            name = File.basename(layout_file).sub(/^([^\.]*).*$/, "\\1")
            @layouts[name] = Layout.new(layout_file)
          end
        end
      end

      def self.[](layout)
        @layouts[layout]
      end

      def initialize(file_path=nil, &block)
        if file_path =~ /\.haml$/
          @template = Tilt::HamlTemplate.new(file_path, {:format => :html5})
        else
          @template = Tilt.new(file_path, &block)
        end
      end

      def render(view, content)
        @template.render(view) {content}
      end
    end

    class DefaultLayout < Layout
      def initialize
        @template = Tilt::StringTemplate.new {DEFAULT}
      end
      DEFAULT = '<!DOCTYPE html>
<html>
<head>
  <title>#{ @page.nav_title } - #{@page.site_title}</title>
  <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
</head>
<body>
#{ yield }
</body>
</html>'
    end

  end
end
