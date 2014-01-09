require 'haml'
require 'tilt'
require 'RedCloth'
require 'rdiscount'

module Amber
  module Render
    class Template

      PROPERTY_HEADER = /^\s*(^(|- )@\w[^\n]*?\n)*/m

      attr_reader :file
      attr_reader :type
      attr_reader :content
      attr_reader :partial

      def initialize(options={})
        if options[:file]
          @file = options[:file]
          @type = type_from_file(@file)
        elsif options[:content]
          @content = options[:content]
          @type    = options[:type]      # e.g. :haml. required if @content
        end
        @partial = options[:partial]
      end

      def render(view)
        locale = view.locals[:locale]
        view.locals[:_type] = @type

        if @type == :haml
          render_haml(@file, view)
        else
          # we need to strip out the property header
          content = @content || File.read(@file).sub(PROPERTY_HEADER, '')

          # first, apply erb always, to give static markup a chance
          # to do something dynamic.
          content = render_erb(content, view)

          # apply static markup filter
          if [:text, :textile].include?(@type)
            render_redcloth(content, view, locale)
          elsif [:md, :markdown].include?(@type)
            render_rdiscount(content, view, locale)
          else
            "sorry, i don't understand how to render #{@type}"
          end
        end
      end

      def render_erb(string, view)
        template = Tilt::ERBTemplate.new {string}
        template.render(view)
      end

      HAML_FORMATS = {
        '.haml'    => :haml
      }

      def render_haml(file_path, view)
        template = Tilt::HamlTemplate.new(file_path, {:format => :html5})
        template.render(view)
      end

      RBST_FORMATS = {
        '.rst'      => :rst
      }

      def render_rbst(string, view, locale)
        html = RbST.new(string).to_html
        unless (title = view.page.explicit_title(locale)).nil?
          html = "<h1 class=\"first\">#{title}</h1>\n\n" + html
        end
        return html
      end

      REDCLOTH_FORMATS = {
        '.txt'      => :textile,
        '.textile'  => :textile
      }

      def render_redcloth(string, view, locale)
        if !@partial
          unless (title = explicit_title(locale)).nil?
            string = "h1(first). #{title}\n\n" + string
          end
        end
        RedCloth.new(string).to_html
      end

      RDISCOUNT_FORMATS = {
        '.md'      => :markdown,
        '.markdown' => :markdown
      }

      def render_rdiscount(string, view, locale)
        rd = RDiscount.new(string, :smart, :generate_toc, :autolink)
        html = rd.to_html
        if !@partial
          if view.page.props.locale(locale).toc != false && rd.toc_content
            #html = "<div id=\"TOC\">%s</div>\n\n%s" % [rd.toc_content.force_encoding('utf-8'), html]
            html = "<div id=\"TOC\">%s</div>\n\n%s" % [rd.toc_content, html]
          end
          unless (title = view.page.explicit_title(locale)).nil?
            html = "<h1 class=\"first\">#{title}</h1>\n\n" + html
          end
        end
        return html
      end

      private

      def type_from_file(file_path)
        suffix = File.extname(file_path)
        if suffix
          suffix.sub! /^\./, ''
          suffix = suffix.to_sym
        end
        suffix
      end

    end
  end
end