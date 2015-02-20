module Amber
  module Render
    module BlogHelper

      def recent_summaries(options={}, &block)
        limit = options[:limit] || @site.pagination_size
        order = options[:order] || :posted_at
        direction = options[:direction] || :desc
        partial = options[:partial]
        if options[:path]
          @site.find_page(options[:path])
        else
          root = @site.root
        end
        if root
          pages = root.all_children.order_by(order, :direction => direction).limit(limit)
          haml do
            pages.each do |page|
              if block
                yield page
              else
                render_page_summary(page)
              end
            end
          end
        end
      end

      #@def news_feed_link
      #  link_to(image_tag('/img/feed-icon-14x14.png'), "/#{I18n.locale}/news.atom")
      #end

    end
  end
end
