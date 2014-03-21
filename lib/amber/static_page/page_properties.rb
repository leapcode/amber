#
# Holds many PropertySets for a StaticPage, one PropertySet per locale.
#
# setting the property (in en.haml):
#
#   - @title = 'hi'
#
# getting the property
#
#   page.props.title                # Uses I18n.locale
#   page.props.prop(:es, :title)    # explicitly uses locale :es
#

require 'i18n'
require 'time'
require 'rubygems'
require 'haml'
require 'RedCloth'

module Amber
  class StaticPage
    class PageProperties

      def initialize(page=nil)
        @page = page
        @locales = {}
      end

      #
      # evaluate the template_string, and load the variables defined into an AttrObject.
      #
      def eval(template_string, locale=I18n.default_locale)
        locale = locale.to_sym # locales are always symbols

        # render to the template to get the instance variables
        ps = PropertySet.new
        begin
          # template is evaluated with binding of ps object
          Haml::Engine.new(template_string, :format => :html5).render(ps)
        rescue Exception => exc
          raise exc if defined?(TESTING)
        end

        # convert date/time variables to objects of class Time
        ps.instance_variables.grep(/_at$/).each do |time_variable|
          ps.instance_variable_set(time_variable, Time.parse(ps.instance_variable_get(time_variable)))
        end

        # save the AttrObject
        @locales[locale] = ps
      end

      #
      # allows property_set.propname shortcut, assumes default locale
      #
      def method_missing(method)
        prop(I18n.locale, method)
      end

      #def locale(l)
      #  @locales[l.to_sym] || @locales[I18n.default_locale]
      #end

      #
      # get an attribute value for a particular locale.
      # if `inherited` is true, we do not consider special non-inheritable properties.
      #
      def prop(locale, var_name, inherited=false)
        return nil unless locale
        properties = @locales[locale.to_sym]
        value = (properties.get(var_name, inherited) if properties)
        if value.nil? && locale != I18n.default_locale
          properties = @locales[I18n.default_locale]
          value = properties.get(var_name, inherited) if properties
        end
        if value.nil? && @page && @page.parent
          value = @page.parent.prop(locale, var_name,  true)
        end
        value
      end

      #
      # like prop(), but does not allow inheritance
      #
      def prop_without_inheritance(locale, var_name)
        properties = @locales[locale.to_sym]
        if properties
          properties.get(var_name)
        else
          nil
        end
      end

      #
      # like prop_without_inheritance, but defaults to default_locale and tries multiple properties
      #
      def prop_with_fallback(locale, var_names)
        [locale, I18n.default_locale].each do |l|
          var_names.each do |var|
            value = prop_without_inheritance(l, var)
            return value if value
          end
        end
        return nil
      end

      def set_prop(locale, var_name, value)
        properties = @locales[locale.to_sym]
        if properties
          properties.set(var_name, value)
        end
      end

      #
      # tries to get the value of an inherited variable
      #
      #def get_inherited_var(var_name, locale=I18n.locale)
      #  if @page && @page.parent && @page.parent.props
      #    @page.parent.props.get_var(var_name, locale)
      #  end
      #end
    end
  end
end