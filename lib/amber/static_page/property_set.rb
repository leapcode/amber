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
      def get(var_name, inheritable_only=false)
        if inheritable_only || @this.nil?
          instance_variable_get("@#{var_name}")
        else
          @this.get(var_name, false) || instance_variable_get("@#{var_name}")
        end
      end

      def set(var_name, value)
        instance_variable_set("@" + var_name.to_s.sub(/=$/, ''), value)
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