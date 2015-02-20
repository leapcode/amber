module Amber
  module Render
    module HtmlHelper
      def time_tag(date_or_time, *args, &block)
        options  = args.last.is_a?(Hash) ? args.pop : {}
        format   = options.delete(:format) || :long
        content  = args.first || I18n.l(date_or_time, :format => format)
        #datetime = date_or_time.acts_like?(:time) ? date_or_time.xmlschema : date_or_time.iso8601
        datetime = date_or_time.iso8601
        content_tag(:time, content, {:datetime => datetime}.merge(options), &block)
      end
    end
  end
end