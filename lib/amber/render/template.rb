require 'haml'
require 'tilt'
require 'RedCloth'
require 'rdiscount'

module Amber
  module Render
    class Template

      PROPERTY_HEADER = /^\s*(^(|- )@\w[^\n]*?\n)*/m

      RENDER_MAP = {
        :text => 'render_textile',
        :textile => 'render_textile',
        :md => 'render_markdown',
        :markdown => 'render_markdown'
      }

      TEXTILE_TOC_RE = /^\s*h([1-6])\.\s+(.*)/

      ERB_TAG_RE = /<%=.*?%>/
      ERB_PLACEHOLDER_RE = /xx erb tag\d+ xx/

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

      #
      # returns rendered content or title, depending on render_type
      #
      def render(view, render_type=nil)
        view.locals[:_type] = @type

        if render_type == :title
          render_title(view)
        elsif @type == :haml
          render_haml(@file, view)
        else
          # load content and strip out the property header
          @content ||= File.read(@file).sub(PROPERTY_HEADER, '')

          # render content
          if method = RENDER_MAP[@type]
            content, erb_tags = replace_erb_tags(@content)
            html = self.send(method, view, content)
            render_erb(restore_erb_tags(html, erb_tags), view)
          else
            "sorry, i don't understand how to render #{@type}"
          end
        end
      end

      #
      # same as render(), but only returns the table of contents, if available.
      # used when we want to insert the toc from one page into the content of a different page.
      #
      def render_toc(view, options={})
        @content ||= File.read(@file)
        if method = RENDER_MAP[@type]
          self.send(method + '_toc', view, @content, options)
        else
          ""
        end
      end

      private

      def render_erb(string, view)
        template = Tilt::ERBTemplate.new {string}
        template.render(view)
      end

      #
      # takes raw markup, and replaces every <%= x %> with a
      # markup-safe placeholder. erb_tags holds a map of placeholder
      # to original erb. e.g. {"ERBTAG0" => "<%= 'hi' %>"}
      #
      def replace_erb_tags(content)
        counter = 0
        erb_tags = {}
        new_content = content.gsub(ERB_TAG_RE) do |match|
          placeholder = "xx erb tag#{counter} xx"
          erb_tags[placeholder] = match
          counter+=1
          placeholder
        end
        return [new_content, erb_tags]
      end

      #
      # replaces erb placeholders with actual erb
      #
      def restore_erb_tags(html, erb_tags)
        html.gsub(ERB_PLACEHOLDER_RE) do |match|
          erb_tags[match]
        end
      end

      def render_title(view)
        locale = view.locals[:locale]
        if title = view.page.explicit_title(locale)
          "<h1>#{title}</h1>\n"
        else
          ""
        end
      end

      def render_haml(file_path, view)
        template = Tilt::HamlTemplate.new(file_path, {:format => :html5})
        template.render(view)
      end

      #def render_rbst(string, view, locale)
      #  html = RbST.new(string).to_html
      #  unless (title = view.page.explicit_title(locale)).nil?
      #    html = "<h1 class=\"first\">#{title}</h1>\n\n" + html
      #  end
      #  return html
      #end

      def render_textile(view, content)
        if @partial
          return RedCloth.new(content).to_html
        else
          locale = view.locals[:locale]
          toc = view.page.prop(locale, :toc)
          if toc != false
            toc_html = generate_toc_from_textile(content)
            content  = add_toc_links_to_textile(content)
          end
          html = RedCloth.new(content).to_html
          html = Autolink.auto_link(html)
          if toc != false
            return add_toc_to_html(html, toc_html)
          else
            return html
          end
        end
      end

      # render only the toc
      def render_textile_toc(view, content, options)
        generate_toc_from_textile(content, options)
      end

      def render_markdown(view, content)
        rd = RDiscount.new(content, :smart, :generate_toc, :autolink)
        html = rd.to_html
        if !@partial
          locale = view.locals[:locale]
          if view.page.prop(locale, :toc) != false && rd.toc_content
            html = add_toc_to_html(html, rd.toc_content)
          end
        end
        return html
      end

      # render only the toc
      def render_markdown_toc(view, content)
        rd = RDiscount.new(content, :generate_toc)
        rd.toc_content
      end

      def add_toc_to_html(html, toc)
        "<div id=\"TOC\">%s</div>\n\n%s" % [toc.force_encoding('utf-8'), html]
      end

      def generate_toc_from_textile(content, options={})
        toc = ""
        base = options[:href_base] || ""
        content.gsub(TEXTILE_TOC_RE) do |match|
          heading_depth = $1
          label = $2.gsub('"', '&quot;')
          anchor = nameize_str(label)
          indent = '#' * heading_depth.to_i
          toc << %(#{indent} ["#{label}":#{base}##{anchor}]\n)
        end
        RedCloth.new(toc).to_html
      end

      def add_toc_links_to_textile(content)
        content.gsub(TEXTILE_TOC_RE) do |match|
          heading_depth = $1
          label = $2
          anchor = nameize_str(label)
          %(\nh#{heading_depth}. <a name="#{anchor}"></a> #{label})
        end
      end

      def type_from_file(file_path)
        suffix = File.extname(file_path)
        if suffix
          suffix.sub! /^\./, ''
          suffix = suffix.to_sym
        end
        suffix
      end

      #
      # convert any string to one suitable for a url.
      # resist the urge to translit non-ascii slugs to ascii.
      # it is always much better to keep strings as utf8.
      #
      def nameize_str(str)
        str = str.dup
        str.gsub!(/&(\w{2,6}?|#[0-9A-Fa-f]{2,6});/,'') # remove html entitities
        str.gsub!(/[^\w\+]+/, ' ') # all non-word chars to spaces
        str.strip!            # ohh la la
        str.downcase!         # upper case characters in urls are confusing
        str.gsub!(/\ +/, '-') # spaces to dashes, preferred separator char everywhere
        str
      end
    end
  end
end