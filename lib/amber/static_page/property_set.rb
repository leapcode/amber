#
# A simple class to hold a set of properties for a page.
#
# There is a separate property set for each locale. The PageProperties object holds many PropertySets, one
# for each locale.
#
# When the template for a page is evaluated, all the member variabled defined in that template
# are loaded as member variables of the PropertySet instance. (e.g. properties are eval'ed
# in context of PropertySet instance)
#
# the "@this" variable is to set variables that should not be inherited
#

module Amber
  class StaticPage
    class PropertySet

      def initialize
        @this = ThisPropertySet.new
      end

      def method_missing(method, *args)
        if method =~ /=$/
          set(method, args.first)
        else
          get(method)
        end
      end

      def textile(str)
        RedCloth.new(str).to_html
      end

      #
      # get the value of a property
      #
      # the @this properties are non-inheritable. If `inheritable_only` is true, we don't consider them
      # when returning the property value.
      #
      def get(property_name, inheritable_only=false)
        if inheritable_only || @this.nil?
          instance_variable_get("@#{property_name}")
        else
          value = @this.get(property_name)
          if value.nil?
            value = instance_variable_get("@#{property_name}")
          end
          value
        end
      end

      #
      # set the value of a property
      #
      # if the property has a non-nil value set in the @this prop set, then we set it there.
      # otherwise, it is set in the inheritable set.
      #
      def set(property_name, value)
        property_name = property_name.to_s.sub(/=$/, '')
        instance_variable = "@" + property_name
        if @this.nil? || @this.get(property_name).nil?
          instance_variable_set(instance_variable, value)
        else
          @this.instance_variable_set(instance_variable, value)
        end
      end

      def to_s
        "<" + instance_variables.map{|v| "#{v}=#{instance_variable_get(v)}"}.join(', ') + ">"
      end
    end

    class ThisPropertySet < PropertySet
      def initialize
      end
    end
  end
end