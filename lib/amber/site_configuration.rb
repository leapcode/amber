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
    attr_accessor :mount_points

    attr_accessor :root_dir
    attr_accessor :pages_dir
    attr_accessor :dest_dir
    attr_accessor :config_dir
    attr_accessor :config_file
    attr_accessor :path
    attr_accessor :menu_file
    attr_accessor :locales_dir
    attr_accessor :timestamp

    ##
    ## CLASS METHODS
    ##

    def self.load(root, options={})
      SiteConfiguration.new(root, options)
    end

    ##
    ## INSTANCE METHODS
    ##

    #
    # accepts a file_path to a configuration file.
    #
    def initialize(root, options={})
      @root_dir    = root
      @pages_dir   = File.join(@root_dir, 'pages')
      @dest_dir    = File.join(@root_dir, 'public')
      @config_dir  = File.join(@root_dir, 'amber')
      @config_file = config_path('config.rb')
      @menu_file   = config_path('menu.txt')
      @locales_dir = config_path('locales')
      @layouts_dir = config_path('layouts')
      @path = '/'
      @mount_points = []
      @mount_points << self
      @title = "untitled"
      @pagination_size = 20
      self.eval
      reset_timestamp
      Render::Layout.load(@layouts_dir)
    end

    #def include_site(directory_source, options={})
    #  @mount_points << SiteMountPoint.new(self, directory_source, options)
    #end

    def pages_changed?
      @mount_points.detect {|mp| mp.changed?}
    end

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

  end
end