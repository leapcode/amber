#
# A class for a site's configuration.
# Site configuration file is eval'ed in the context of an instance of SiteConfiguration
#
# A site can have multiple sub sites, each with their own configurations (called mount points)
#

require 'pathname'

module Amber
  class SiteConfiguration

    attr_accessor :title
    attr_accessor :pagination_size
    attr_accessor :locales
    attr_accessor :default_locale
    attr_accessor :path_prefix
    alias :path :path_prefix
    attr_accessor :short_paths

    attr_accessor :menu

    attr_accessor :root_dir
    attr_accessor :pages_dir
    attr_accessor :dest_dir
    attr_accessor :config_dir
    attr_accessor :config_file
    attr_accessor :layouts_dir
    attr_accessor :path
    attr_accessor :menu_file
    attr_accessor :locales_dir
    attr_accessor :timestamp

    # an array of SiteConfigurations that are attached as sub-sites
    # to this one.
    attr_accessor :children

    extend Forwardable
    def_delegators :@site, :pages, :find_page, :find_pages, :find_page_by_path, :find_page_by_name, :continue_on_error

    ##
    ## CLASS METHODS
    ##

    def self.load(site, root_dir, options={})
      SiteConfiguration.new(site, root_dir, options)
    end

    ##
    ## INSTANCE METHODS
    ##

    #
    # accepts a file_path to a configuration file.
    #
    def initialize(site, root_dir, options={})
      @children = []
      @site = site
      @root_dir = File.expand_path(find_in_directory_tree('amber', 'config.rb', root_dir))
      if @root_dir == '/'
        puts "Could not find amber/config.rb in the directory tree. Run `amber` from inside an amber website directory"
        exit(1)
      end
      @pages_dir   = File.join(@root_dir, 'pages')
      @dest_dir    = File.join(@root_dir, 'public')
      @config_dir  = File.join(@root_dir, 'amber')
      @config_file = config_path('config.rb')
      @menu_file   = config_path('menu.txt')
      @locales_dir = config_path('locales')
      @layouts_dir = config_path('layouts')
      @title = "untitled"
      @pagination_size = 20

      @menu = Menu.new('root')
      @menu.load(@menu_file) if @menu_file

      self.eval
      @path_prefix = options[:path_prefix] if options[:path_prefix]
      self.cleanup

      reset_timestamp
      Render::Layout.load(@layouts_dir)
    end

    #
    # map('/path' => '../othersite')
    #
    def map(path_to_directory_source, options={})
      path, root_dir = path_to_directory_source.to_a.first
      config = self.load(@site, root_dir, {:path_prefix => path})
      @site.add_config(config)
    end

    def cleanup
      @locale ||= I18n.default_locale
      I18n.default_locale = @locale
      @locales ||= [@locale]
      @locales.map! {|locale|
        if Amber::POSSIBLE_LANGUAGE_CODES.include?(locale.to_s)
          locale.to_sym
        else
          nil
        end
      }.compact
      if @path_prefix
        @path_prefix.gsub!(%r{^/|/$}, '')
        @path_prefix = nil if @path_prefix == ''
      end
    end

    #def pages_changed?
    #  self.changed? || @children.detect {|child| child.changed?}
    #end

    def eval
      self.instance_eval(File.read(@config_file), @config_file)
    end

    def config_path(file)
      path = File.join(@config_dir, file)
      if File.exists?(path)
        path
      else
        nil
      end
    end

    def reset_timestamp
      @timestamp = File.mtime(@pages_dir)
    end

    def find_in_directory_tree(target_dir_name, target_file_name, directory_tree=nil)
      search_dir = directory_tree || Dir.pwd
      while search_dir != "/"
        Dir.foreach(search_dir) do |f|
          if f == target_dir_name && File.exists?(File.join(search_dir, f,target_file_name))
            return search_dir
          end
        end
        search_dir = File.dirname(search_dir)
      end
      return search_dir
    end

  end
end