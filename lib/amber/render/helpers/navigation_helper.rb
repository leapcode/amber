module Amber
  module Render
    module NavigationHelper

      def has_navigation?
        if current_page_path.empty? || @site.menu.nil?
          false
        else
          submenu = @site.menu.submenu(current_page_path.first)
          if submenu
            second_level_children_count = submenu.size
            if second_level_children_count.nil?
              false
            else
              second_level_children_count >= 1
            end
          else
            false
          end
        end
      end

      #
      # yields each item
      #
      def top_navigation_items(options={})
        if !@site.menu
          yield({})
        else
          first = 'first'
          if options[:include_home]
            active = current_page_path.empty? ? 'active' : ''
            yield({:class => [first, active].compact.join(' '), :href => amber_path(@site.menu.path), :label => menu_item_title(@site.menu)})
            first = nil
          end
          @site.menu.each do |item|
            active = current_page_path.first == item.name ? 'active' : ''
            yield({:class => [first, active].compact.join(' '), :href => amber_path(item.path), :label => menu_item_title(item)})
            first = nil
          end
        end
      end

      #
      # yields each item
      #
      def navigation_items(menu=nil, level=1, &block)
        if menu.nil?
          menu = site.menu.submenu(current_page_path.first)
        end
        if menu
          menu.each do |item|
            title = menu_item_title(item)
            if title
              yield({
                :href => amber_path(item.path),
                :level => level,
                :active => path_active_class(current_page_path, item),
                :label => title
              })
            end
            if path_open?(current_page_path, item)
              navigation_items(item.submenu, level+1, &block)
            end
          end
        end
      end

      def current_page_path
        @current_page_path ||= begin
          if @page
            @page.path
          #elsif params[:page].is_a? String
          #  params[:page].split('/')
          else
            []
          end
        end
      end

      def menu_item_title(item)
        page = @site.find_page_by_path(item.path_str) || @site.find_page_by_name(item.name)
        if page
          page.nav_title(I18n.locale)
        else
          nil
        end
      end

      #
      # inserts an directory index built from the page's children
      #
      # options:
      #   :levels         -- the max levels to descend (default 1)
      #   :page           -- StaticPage instance or nil
      #   :include_toc    -- true or false (default false)
      #   :order_by       -- arguments to PageArray#order_by
      #   :heading        -- heading level to use (default 2)
      #   :summary        -- to show summaries or not (default true)
      #
      def child_summaries(options={})
        page = options.delete(:page) || @page
        unless page.is_a?(StaticPage)
          page = @site.find_pages(page)
        end
        return "" if page.nil? or page.children.empty?

        levels_max = options[:levels] || 1
        level      = options.delete(:level) || 1
        heading    = options.delete(:heading) || 2
        locale     = @locals[:locale]
        menu       = submenu_for_page(page)
        if menu && menu.children.any?
          children = menu.children
        elsif options[:order_by]
          children = page.children.order_by(*options[:order_by])
        else
          children = page.children
        end

        haml do
          children.each do |child|
            child_page = child.is_a?(Amber::Menu) ? page.child(child.name) : child
            next unless child_page
            render_page_summary(child_page, heading, options)
            if level < levels_max
              haml(child_summaries({
                :page => child_page,
                :levels => levels_max,
                :level => level+1,
                :include_toc => options[:include_toc],
                :order_by => options[:order_by],
                :heading => heading+1,
                :summary => options[:summary]
              }))
            end
          end
        end
      rescue Exception => exc
        Amber.log_exception(exc)
      end

      def render_page_summary(page, heading=2, options={})
        locale = @locals[:locale]
        klass = options[:class] || '.page-summary'
        haml ".#{klass}" do
          haml "h#{heading}" do
            haml :a, page.nav_title(locale), :href => amber_path(page)
          end
          if options[:summary] != false
            if summary = page.prop(locale, 'summary')
              haml '.summary', summary
            elsif preview = page.prop(locale, 'preview')
              haml '.preview', preview
            end
          end
          if options[:include_toc]
            toc_html = render_toc(page, :locale => locale)
            haml toc_html
          end
        end
      end

      private

      #
      # returns string 'active', 'semi-active', or ''
      #
      def path_active_class(page_path, menu_item)
        active = ''
        if menu_item.path == page_path
          active = 'active'
        elsif menu_item.path_prefix_of?(page_path)
          if menu_item.leaf_for_path?(page_path)
            active = 'active'
          else
            active = 'semi-active'
          end
        end
        active
      end

      #
      # returns true if menu_item represents an parent of page
      #
      def path_open?(page_path, menu_item)
        menu_item.path == page_path || menu_item.path_prefix_of?(page_path)
      end

      def submenu_for_page(page)
        menu = @site.menu
        page.path.each do |segment|
          menu = menu.submenu(segment)
        end
        return menu
      rescue
        return nil
      end

    end
  end
end
