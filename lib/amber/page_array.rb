#
# Array of StaticPages
#
class Amber::PageArray < Array
  def limit(num)
    PageArray.new(self[0..(num-1)])
  end
  def order_by(attr, options={})
    locale = options[:locale] || I18n.locale
    direction = options[:direction] || :asc
    array = sort do |a,b|
      if direction == :desc
        a, b = b, a
      end
      a_prop = a.prop(locale, attr)
      b_prop = b.prop(locale, attr)
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
end