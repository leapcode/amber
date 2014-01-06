#
# holds the set or properties defined for each static page.
# property sets are organized by locale.
#
# e.g.
#
# setting the property (in en.haml):
#
#   - @title = 'hi'
#
# getting the property
#
#   page.props.title
#   page.props.locale('en').title
#

require 'i18n'
require 'time'
require 'rubygems'
require 'haml'
require 'RedCloth'

class Amber::PropertySet

  DEFAULT_LOCALE = :en

  #
  # a simple class to pass through all member variables as attributes.
  # when the template for a page is evaluated, all the member variabled defined in that template
  # are loaded as member variables of the AttrObject instance.
  #
  class AttrObject
    def initialize(property_set, locale)
      @_ps = property_set  # underscore is important here, because we don't want to
      @_locale = locale    # accidentally collide with another property that gets set.
    end
    def method_missing(method)
      get(method)
    end
    def textile(str)
      RedCloth.new(str).to_html
    end
    def get(var_name, inheritance=true)
      value = instance_variable_get("@#{var_name}")
      if value.nil?
        if @_locale != DEFAULT_LOCALE
          # try value from default locale
          @_ps.get_var(var_name, DEFAULT_LOCALE)
        elsif inheritance
          # try inherited value
          @_ps.get_inherited_var(var_name, @_locale)
        else
          nil
        end
      else
        value
      end
    end
    def set(var_name, value)
      instance_variable_set("@#{var_name}", value)
    end
  end

  def initialize(page=nil)
    @page = page
    @locales = {}
  end

  #
  # evaluate the template_string, and load the variables defined into an AttrObject.
  #
  def eval(template_string, locale)
    locale ||= DEFAULT_LOCALE
    locale = locale.to_sym # locales are always symbols

    # render to the template to get the instance variables
    attrs = AttrObject.new(self, locale)
    begin
      # template is evaluated with binding of attrs object
      Haml::Engine.new(template_string, :format => :html5).render(attrs)
    rescue Exception => exc
      # eat exceptions
    end

    # convert date/time variables to objects of class Time
    attrs.instance_variables.grep(/_at$/).each do |time_variable|
      attrs.instance_variable_set(time_variable, Time.parse(attrs.instance_variable_get(time_variable)))
    end

    # save the AttrObject
    @locales[locale] = attrs
  end

  #
  # ALTERNATE EVAL
  #
  # body = nil
  # controller = ApplicationController.new()
  # controller.response = ActionController::Response.new()
  # view = ActionView::Base.new(["#{Rails.root}/app/views/pages","#{Rails.root}/app/views"], {}, controller)
  # view.extend ApplicationHelper  # TODO: figure out how to extend all helpers
  # view.extend BlogHelper
  # view.extend HamlHelper
  # view.extend NavigationHelper
  # begin
  #   body = Haml::Engine.new(template_string, :format => :html5).render(view)  # template is evaluated with binding of view object
  # rescue Exception => exc
  #   # eat exceptions
  # end
  #
  # this doesn't work because view doesn't get instance variables set
  #
  # copy new instance variables
  # new_variables = view.instance_variables
  # new_variables = original_instance_variables - view.instance_variables
  # new_variables.each do |variable|
  #   #attrs.instance_variable_set(variable, view.instance_variable_get(variable))
  # end
  #
  # clean up attrs
  # attrs.instance_variable_set('@body', body)
  #

  #
  # allows property_set.propname shortcut, assumes default locale
  #
  def method_missing(method)
    get_var(method)
  end

  def locale(l)
    @locales[l.to_sym] || @locales[DEFAULT_LOCALE]
  end

  def get_var(var_name, locale=I18n.locale)
    attrs = locale(locale)
    if attrs
      attrs.get(var_name)
    else
      nil
    end
  end

  #
  # like get_var, but does not allow inheritance
  #
  def get_var_without_inheritance(var_name, locale=I18n.locale)
    attrs = locale(locale)
    if attrs
      attrs.get(var_name, false)
    else
      nil
    end
  end

  #
  # tries to get the value of an inherited variable
  #
  def get_inherited_var(var_name, locale=I18n.locale)
    if @page && @page.parent && @page.parent.props
      @page.parent.props.get_var(var_name, locale)
    end
  end
end

#
# a simple little test.
#
if ARGV.grep('--test').any?
  text_en = "
- @title = 'hi'
- @author = 'you'
- @created_at = 'Sun Aug 12 18:32:20 PDT 2012'
- ignored = 1
"

  text_es = "
- @title = 'hola'
- @author = 'tu'
- @heading = textile 'h1. hi'
"

  ps = PropertySet.new
  ps.eval(text_en, 'en')
  ps.eval(text_es, 'es')

  p ps.title == 'hi'
  p ps.locale(:es).title == 'hola'
  p ps.get_var('title', 'es') == 'hola'
  p ps.locale(:es).created_at == Time.parse('Sun Aug 12 18:32:20 PDT 2012')
  p ps.ignored == nil
  p ps.locale(:es).ignored == nil
  p ps.locale(:es).heading == "<h1>hi</h1>"
  #p ps.body == "this is the body"
  #p ps.get_var('body', :es) == "esta es el cuerpo"
end
