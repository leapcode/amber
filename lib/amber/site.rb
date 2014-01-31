require 'forwardable'
require 'fileutils'

module Amber
  class Site
    extend Forwardable

    attr_accessor :page_list
    attr_accessor :root

    def_delegators :@config, :dest_dir, :locales, :default_locale

    def initialize(root_dir)
      @config = SiteConfiguration.load(self, root_dir)
    end

    def load_pages
      @root          = nil
      @pages_by_path = {}
      @pages_by_name = {}
      @page_list     = PageArray.new
      @dir_list      = []
      @config.mount_points.each do |mp|
        add_mount_point(mp)
        mp.reset_timestamp
      end
    end

    def reload_pages_if_needed
      if @pages_by_path.nil? || @config.pages_changed?
        puts "Reloading pages ................."
        load_pages
      end
    end

    def render
      @page_list.each do |page|
        page.render_to_file(@config.dest_dir)
        putc '.'; $stdout.flush
      end
      @dir_list.each do |directory|
        src = File.join(@config.pages_dir, directory)
        dst = File.join(@config.dest_dir, directory)
        Render::Asset.render_dir(src, dst)
        putc '.'; $stdout.flush
      end
      puts
    end

    def clear
      Dir.glob("#{@config.dest_dir}/*").each do |file|
        FileUtils.rm_r(file)
      end
    end

    def find_pages(filter)
      StaticPage.find(self, filter)
    end

    def find_page(filter)
      find_pages(filter)
    end

    def all_pages
      @page_list
    end

    def find_page_by_path(path)
      @pages_by_path[path]
    end

    def find_page_by_name(name)
      @pages_by_name[name]
    end

    private

    def add_mount_point(mp)
      # create base_page
      base_page = begin
        if mp.path == '/'
          @root = StaticPage.new(nil, 'root', mp.pages_dir)
          add_page(@root)
          @root
        else
          name = File.basename(mp.path)
          page = StaticPage.new(find_parent(mp.path), name, mp.pages_dir)
          add_page(page)
          page
        end
      end
      base_page.mount_point = mp

      # load menu and locals
      I18n.load_path += Dir[File.join(mp.locales_dir, '/*.{rb,yml,yaml}')] if mp.locales_dir

      # add the full directory tree
      base_page.scan_directory_tree do |page, asset_dir|
        add_page(page) if page
        @dir_list << asset_dir if asset_dir
      end
    end

    def add_page(page)
      @pages_by_name[page.name] = page
      @pages_by_path[page.path.join('/')] = page
      page.aliases.each do |alias_path|
        if @pages_by_path[alias_path]
          Amber.logger.warn "WARNING: page `#{page.path.join('/')}` has alias `#{alias_path}`, but this path is already taken"
        else
          @pages_by_path[alias_path] = page
        end
      end
      @page_list << page
    end

    def find_parent(path)
      so_far = []
      path.split('/').compact.each do |path_segment|
        so_far << path_segment
        if page = @pages_by_path[so_far.join('/')]
          return page
        end
      end
      return @root
    end

  end
end