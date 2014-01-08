require 'forwardable'
require 'fileutils'

module Amber
  class Site
    extend Forwardable

    attr_accessor :pages
    attr_accessor :page_list
    attr_accessor :root
    attr_accessor :menu

    def_delegators :@config, :title, :pagination_size

    def initialize(root)
      @config = SiteConfiguration.load(root)
    end

    def load_pages
      @root      = nil
      @pages     = {}
      @page_list = StaticPageArray.new
      @menu      = Menu.new('root')
      @config.mount_points.each do |mp|
        add_mount_point(mp)
        mp.reset_timestamp
      end
    end

    def reload_pages_if_needed
      if @pages.nil? || @config.pages_changed?
        puts "Reloading pages ................."
        load_pages
      end
    end

    def render
      @page_list.each do |page|
        updated_files = page.render_to_file(@config.dest_dir)
      end
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
      menu.load(mp.menu_file) if mp.menu_file
      I18n.load_path += Dir[File.join(mp.locales_dir, '/*.{rb,yml,yaml}')] if mp.locales_dir

      # add the full directory tree
      scan_tree(base_page) do |page|
        add_page(page)
      end
    end

    def add_page(page)
      @pages[page.name] = page
      @pages[page.path.join('/')] = page
      @page_list << page
    end

    def find_parent(path)
      so_far = []
      path.split('/').compact.each do |path_segment|
        so_far << path_segment
        if page = @pages[so_far.join('/')]
          return page
        end
      end
      return @root
    end

    private

    #
    # loads a directory, creating StaticPages from the directory structure,
    # yielding each StaticPage as it is created.
    #
    def scan_tree(page, &block)
      Dir.chdir(page.file_path) do
        Dir.glob("*").each do |child_name|
          if File.directory?(child_name)
            child = StaticPage.new(page, child_name)
            yield child
            scan_tree(child, &block)
          elsif StaticPage.is_simple_page?(child_name)
            child = StaticPage.new(page, child_name)
            yield child
          end
        end
      end
    end

  end
end