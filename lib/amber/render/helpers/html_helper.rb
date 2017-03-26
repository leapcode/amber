module Amber
  module Render
    module HtmlHelper

      #
      # return html markup suitable for setting the href base
      # of the document. If this is added to the document's HEAD,
      # then relative urls will work as expected even though the
      # url path does not end with a '/'
      #
      def html_head_base
        if @page
          "<base href=\"#{amber_path(@page)}/\" />"
        else
          ""
        end
      end

      #
      # link_to like rails
      def link_to(label, url, options=nil)
        link({label => url}, options)
      end

      #
      # three forms:
      #
      #  (1) link('page-name')
      #  (2) link('label' => 'page-name')
      #  (3) link('label' => 'https://url')
      #
      # both accept optional options hash:
      #
      #  (1) link('page-name', :class => 'x')
      #  (2) link('label' => 'page-name', :class => 'x')
      #
      def link(name, options=nil)
        options = nil if options && !options.is_a?(Hash)
        klass = nil
        if name.is_a? Hash
          klass = name.delete(:class)
          label, name = name.to_a.first
          if label.is_a? Symbol
            label = I18n.t label
          end
        end
        klass ||= options[:class] if options
        if name =~ /^#/ || name =~ /^http/ || name =~ /\./
          path = name
          label ||= name
        else
          if index = name.index('#')
            anchor = name[index..-1]
            name_without_anchor = name[0..(index-1)]
          else
            anchor = ''
            name_without_anchor = name
          end
          page = @site.find_page(name_without_anchor)
          if page
            label ||= page.nav_title
            path = amber_path(page) + anchor
          else
            puts "warning: dead link to `#{name_without_anchor}` from page `/#{I18n.locale}/#{@page.path.join('/')}`"
            label ||= name_without_anchor
            label += ' [dead link]'
            path = name_without_anchor
          end
        end
        if klass
          %(<a href="#{path}" class="#{klass}">#{label}</a>)
        else
          %(<a href="#{path}">#{label}</a>)
        end
      end

      #
      # returns the ideal full url path for a page or path (expressed as an array).
      #
      def amber_path(page_or_array, locale=I18n.locale)
        page = nil
        if page_or_array.is_a? Array
          page = @site.find_page_by_path(page_or_array)
        elsif page_or_array.is_a? StaticPage
          page = page_or_array
        end
        if page.nil?
          return ''
        end
        full_path = []
        full_path << @site.path_prefix if @site.path_prefix
        full_path << locale # always do this?
        if page.aliases(locale).any?
          full_path += page.aliases(locale).first
        else
          full_path += page.path
        end
        "/" + full_path.join('/')
      end

    end
  end
end
