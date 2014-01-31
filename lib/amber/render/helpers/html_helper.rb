module Amber
  module Render
    module HtmlHelper

      def html_head_base
        href = (['..'] * @page.path.count).join('/')
        "<base href=\"#{href}\" />"
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
        if name.is_a? Hash
          klass = name.delete(:class)
          label, name = name.to_a.first
          if label.is_a? Symbol
            label = I18n.t label
          end
        else
          klass = options[:class] if options
        end
        if name =~ /^#/ || name =~ /^http/
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
            label ||= page.title
            path = page_path(page) + anchor
          else
            puts "warning: dead link to `#{name_without_anchor}` from page `/#{I18n.locale}/#{@page.path.join('/')}`"
            label ||= name_without_anchor
            label += ' [dead link]'
            path = '/'
          end
        end
        if klass
          %(<a href="#{path}" class="#{klass}">#{label}</a>)
        else
          %(<a href="#{path}">#{label}</a>)
        end
      end

      #
      # returns the shortest possible path. this would be nice to support some day, but more difficult with statically rendered sites.
      #
      def page_path(page, locale=I18n.locale)
        if page.prop(locale, :alias)
          "/#{locale}/#{page.prop(locale, :alias).first}/#{page.name}"
        else
          "/#{locale}/#{page.path.join('/')}"
        end
      end

    end
  end
end
