#
# Array of StaticPages
#

require 'bigdecimal'

module Amber
  class PageArray < Array

    def limit(num)
      PageArray.new(self[0..(num-1)])
    end

    #
    # available options:
    #
    # :locale    -- the locale to use when comparing attributes
    # :direction -- either :asc or :desc
    # :numeric   -- if true, attributes are cast as numbers before comparison
    #
    def order_by(attr, options={})
      locale = options[:locale] || I18n.locale
      direction = options[:direction] || :asc
      array = sort do |a,b|
        if direction == :desc
          a, b = b, a
        end
        a_prop = a.prop(locale, attr)
        b_prop = b.prop(locale, attr)
        if options[:numeric]
          a_prop = to_numeric(a_prop)
          b_prop = to_numeric(b_prop)
        end
        if a_prop.nil? && b_prop.nil?
          0
        elsif a_prop.nil?
          1
        elsif b_prop.nil?
          -1
        else
          a_prop <=> b_prop
        end
      end
      # remove pages from the results that have no value set for the attr
      array.delete_if do |page|
        page.prop(locale, attr).nil?
      end
      return PageArray.new.replace array
    end

    def to_numeric(anything)
      num = BigDecimal.new(anything.to_s)
      if num.frac == 0
        num.to_i
      else
        num.to_f
      end
    end

  end
end