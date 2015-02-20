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
        :markdown => 'render_markdown',
        :html => 'render_raw',
        :raw  => 'render_raw',
        :none => 'render_none',
        :erb => 'render_none'
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
          @type = options[:type] || type_from_file(@file)
        elsif options[:content]
          @content = options[:content]
          @type    = options[:type]      # e.g. :haml. required if @content
        end
        @partial = options[:partial]
      end

      #
      # returns rendered content or title, depending on render_mode
      #
      def render(view, options={})
        view.locals[:_type] = @type
        render_mode = options.delete(:mode) || :content
        toc = options.delete(:toc)
        if render_mode == :title
          render_title(view)
        else
          html = render_html(view)
          if render_mode == :toc
            RegexTableOfContents.new(html, options).to_toc
          elsif toc === false
            html
          elsif toc || render_mode == :toc_and_content
            toc = RegexTableOfContents.new(html, options)
            %(<div id="TOC">%s</div>\n\n%s) % [toc.to_toc, toc.to_html]
          else
            html
          end
        end
      end

      private

      def render_html(view)
        if @type == :haml
          return render_haml(@file, view)
        else
          @content ||= File.read(@file, :encoding => 'UTF-8').sub(PROPERTY_HEADER, '')  # remove property header
          if method = RENDER_MAP[@type]
            content, erb_tags = replace_erb_tags(@content)
            html = self.send(method, view, content)
            return render_erb(restore_erb_tags(html, erb_tags), view)
          else
            return "sorry, i don't understand how to render `#{@type}`"
          end
        end
      end

      def render_erb(string, view)
        template = Tilt::ERBTemplate.new {string}
        template.render(view)
      end

      #
      # takes raw markup, and replaces every <%= x %> with a
      # markup-safe placeholder. erb_tags holds a map of placeholder
      # to original erb. e.g. {"ERBTAG0" => "<%= 'hi]]"}
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
        template = Tilt::HamlTemplate.new(file_path, {:format => :html5, :default_encoding => 'UTF-8'})
        add_bracket_links(view, template.render(view, view.locals))
      end

      def render_textile(view, content)
        content = add_bracket_links(view, content)
        Autolink.auto_link(RedCloth.new(content).to_html)
      end

      def render_markdown(view, content)
        content = add_bracket_links(view, content)
        RDiscount.new(content, :smart, :autolink).to_html
      end

      def render_raw(view, content)
        add_bracket_links(view, content)
      end

      def render_none(view, content)
        content
      end

      def add_bracket_links(view, content)
        content = Bracketlink.bracket_link(content) do |from, to|
          view.link({from => to})
        end
        content
      end

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