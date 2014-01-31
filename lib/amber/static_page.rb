#
# class StaticPage
#
# represents a static website page.
# see also static_page/*.rb
#

module Amber
  class StaticPage

    attr_accessor :path,    # array of path segments
      :children,            # array of child pages
      :name,                # the name of the page
      :file_path,           #
      :parent,              # parent page (nil for root page)
      :mount_point,         # associated SiteConfiguration
      :site,                # associated Site
      :locales,             # currently unused
      :locale               # if the source page is only in a single locale

    attr_reader :props      # set of page properties (PropertySet)

    ##
    ## CLASS METHODS
    ##

    def self.find(site, filter)
      if filter =~ /\//
        path = filter.split('/').map{|segment| segment.gsub(/[^0-9a-z_-]/, '')}
        page = site.find_page_by_path(path.join('/'))
        if page
          return page
        else
          return site.find_page_by_name(path.last)
        end
      else
        site.find_page_by_name(filter)
      end
    end

    ##
    ## INSTANCE METHODS
    ##

    def initialize(parent, name, file_path=nil)
      @children = PageArray.new  # array of StaticPages
      @nav_title = {} # key is locale
      @title = {}     # key is locale

      @name, @locale, @suffix = parse_source_file_name(name)

      # set @parent & @path
      if parent
        @parent = parent
        @mount_point = @parent.mount_point
        @parent.add_child(self)
        @path = [@parent.path, @name].flatten.compact
      else
        @path = []
      end

      # set the @file_path
      if file_path
        @file_path = file_path
      elsif @parent && @parent.file_path
        @file_path = File.join(@parent.file_path, @name)
      else
        raise 'file path must be specified or in parent'
      end

      # discover supported locales
      @simple_page = !File.directory?(@file_path)
      #@locales = find_locales()

      # eval the property headers, if any
      @props = load_properties()
    end

    def add_child(page)
      @children << page
    end

    def all_children
      PageArray.new(child_tree.flatten.compact)
    end

    def inspect
      "<'#{@path.join('/')}' #{children.inspect}>"
    end

    def title(locale=I18n.locale)
      @title[locale] ||= begin
        @props.prop_without_inheritance(locale, :title) ||
        @props.prop_without_inheritance(locale, :nav_title) ||
        @name
      end
    end

    def nav_title(locale=I18n.locale)
      @nav_title[locale] ||= begin
        @props.prop_without_inheritance(locale, :nav_title) ||
        @props.prop_without_inheritance(locale, :title) ||
        @props.prop_without_inheritance(I18n.default_locale, :nav_title) ||
        @props.prop_without_inheritance(I18n.default_locale, :title) ||
        @name
      end
    end

    #
    # returns title iff explicitly set.
    #
    def explicit_title(locale)
      @props.prop_without_inheritance(locale, :title) ||
      @props.prop_without_inheritance(I18n.default_locale, :title)
    end

    def id
      self.name
    end

    #
    # returns a child matching +name+, if any.
    #
    def child(name)
      children.detect {|child| child.name == name}
    end

    def prop(*args)
      @props.prop(*args)
    end

    #
    # returns an array of normalized aliases based on the :alias property
    # defined for a page.
    #
    # aliases are defined with a leading slash for absolute paths, or without a slash
    # for relative paths. this method converts this to a format that amber uses
    # (all absolute, with no leading slash).
    #
    # currently, we do not maintain per-locale paths or aliases.
    #
    def aliases
      @aliases ||= begin
        if @props.alias.nil?
          []
        else
          @props.alias.collect {|alias_path|
            if alias_path =~ /^\//
              alias_path.sub(/^\//, '')
            elsif @parent
              (@parent.path + [alias_path]).join('/')
            else
              alias_path
            end
          }
        end
      end
    end

    protected

    def child_tree
      [self, children.collect{|child| child.child_tree}]
    end

  end
end