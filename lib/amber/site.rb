require 'forwardable'
require 'fileutils'

module Amber
  class Site
    extend Forwardable

    attr_accessor :page_list
    attr_accessor :root
    attr_accessor :continue_on_error

    def_delegators :@config, :dest_dir, :locales, :default_locale, :path_prefix

    def initialize(root_dir)
      @continue_on_error = true
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
      if @config.short_paths
        render_short_path_symlinks
      end
      Render::Apache.write_htaccess(@config, @config.dest_dir)
      puts
    end

    def clear
      Dir.glob("#{@config.dest_dir}/*").each do |file|
        FileUtils.rm_r(file)
      end
    end

    def with_destination(new_dest)
      dest_dir = @config.dest_dir
      @config.dest_dir = new_dest
      yield
      @config.dest_dir = dest_dir
    end

    def find_pages(filter)
     filter = filter.downcase
     if filter =~ /\//
        path = filter.split('/').map{|segment| segment.gsub(/[^0-9a-z_-]/, '')}
        path_str = path.join('/')
        if (page = @pages_by_path[path_str])
          page
        elsif matched_path = @page_paths.grep(/#{Regexp.escape(path_str)}/).first
          @pages_by_path[matched_path]
        elsif page = @pages_by_name[path.last]
          page
        else
          nil
        end
      else
        @pages_by_name[filter]
      end
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

    #
    # returns the shortest possible path for a page, such that the path doesn't collide with
    # another page or another page's aliases.
    #
    def shortest_path(page)
      path_so_far = []
      page.path.reverse.each do |path_segment|
        path_so_far.push(path_segment)
        path_str = path_so_far.join('/')
        if @pages_by_path[path_str].nil? && short_paths[path_str] == page
          return path_so_far
        end
      end
      return []
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
      @page_paths = @pages_by_path.keys
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

    #
    # adds symlinks for all possible 'short paths' for every page.
    # this works by:
    # (1) examine all pages in order of longest path depth and assign 'short paths' for each page.
    # (2) examine all short paths in order of shortest path depth and create symlinks
    #
    def render_short_path_symlinks
      short_paths.each do |path, page|
        page.link_page_aliases(@config.dest_dir, [path])
      end
    end

    #
    # returns a hash containing all the automatically determined shortest paths for every page.
    # the data structure looks like so:
    #
    # {
    #   "ddd" => <page 'bbb/ddd'>,
    #   "ccc" => <page 'bbb/ccc'>,
    #   "red" => <page 'autoalias/red'>,
    #   "blue"=> <page 'autoalias/blue'>,
    #   "red/blue" => <page 'autoalias/red/blue'>
    # }
    #
    # short_paths does not include the normal paths or normal aliases, just the automatic short path aliases.
    #
    def short_paths
      @short_paths ||= begin
        shortpaths = {}
        pages_in_depth_order = @page_list.collect{ |page|
          {:page => page, :path => page.path.dup, :depth => page.path.length} if page.path.length > 1
        }.compact.sort {|a,b| a[:depth] <=> b[:depth]}
        pages_in_depth_order.each do |record|
          record[:depth].times do |depth|
            record[:path].shift
            path = record[:path].join('/')
            if @pages_by_path[path].nil? && shortpaths[path].nil?
              shortpaths[path] = record[:page]
            end
          end
        end
        # debug:
        #shortpaths.each do |path, record|
        #  puts "#{record[:page].path.join('/')} => #{record[:path].join('/')}"
        #end
        shortpaths
      end
    end

  end
end