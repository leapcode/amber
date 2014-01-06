#
# Array of StaticPages
#
class Amber::StaticPageArray < Array
  def limit(num)
    StaticPageArray.new(self[0..(num-1)])
  end
  def order_by(attr, options={})
    locale = options[:locale] || I18n.locale
    direction = options[:direction] || :asc
    array = sort do |a,b|
      if direction == :desc
        a, b = b, a
      end
      a_prop = a.props.locale(locale).send(attr)
      b_prop = b.props.locale(locale).send(attr)
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
      page.props.locale(locale).send(attr).nil?
    end
    return StaticPageArray.new.replace array
  end
end