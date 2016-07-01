require 'forwardable'
require 'fileutils'

module Amber
  class Site
    extend Forwardable

    attr_accessor :page_list
    attr_accessor :root
    attr_accessor :continue_on_error

    # @config is the primary SiteConfiguration
    def_delegators :@config, :pages_dir, :dest_dir, :locales, :default_locale, :path_prefix

    def initialize(root_dir)
      @continue_on_error = true
      @config = SiteConfiguration.load(self, root_dir)
    end

    def add_config(config)
      @config.children << config
    end

    def load_pages
      @root          = nil
      @pages_by_path = {}  # hash of pages keyed by page path
      @pages_by_name = {}  # hash of pages keyed by page name
      @page_list     = PageArray.new
      @dir_list      = []  # an array of non-page directories
      @page_paths    = []  # an array of page paths, used for greping through paths.

      # some paths are specific to only one locale (e.g aliases)
      @pages_by_locale_path = POSSIBLE_LANGUAGES.keys.inject(Hash.new({})) {|h,locale| h[locale] = {}; h}

      add_configuration(@config)
    end

    #def reload_pages_if_needed
    #  if @pages_by_path.nil? || @config.pages_changed?
    #    puts "Reloading pages ................."
    #    load_pages
    #  end
    #end

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
      Render::Apache.write_htaccess(@config, @config.pages_dir, @config.dest_dir)
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

    #
    # find pages by a filter.
    # filter is a string composing a path segment.
    # For example:
    #   "chat/security"
    # Which would match "/services/chat/security" but not "/services/security"
    #
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

    def find_page_by_path(path, locale=I18n.default_locale)
      if locale.is_a? String
        if I18n.locale_available?(locale)
          locale = locale.to_sym
        end
      end
      if path.is_a? Array
        path = path.join('/')
      end
      @pages_by_locale_path[locale][path] || @pages_by_path[path]
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

    def add_configuration(config)
      config.reset_timestamp

      # create base_page
      base_page = begin
        if config.path.nil?
          @root = StaticPage.new(nil, 'root', config.pages_dir)
          add_page(@root)
          @root
        else
          name = File.basename(config.path)
          sub_root = StaticPage.new(find_parent(config.path), name, config.pages_dir, config.path_prefix)
          add_page(sub_root)
          sub_root
        end
      end
      base_page.config = config

      # load menu and locals
      I18n.load_path += Dir[File.join(config.locales_dir, '/*.{rb,yml,yaml}')] if config.locales_dir

      # add the full directory tree
      base_page.scan_directory_tree do |page, asset_dir|
        add_page(page) if page
        @dir_list << asset_dir if asset_dir
      end
      @page_paths += @pages_by_path.keys

      # recursively add sub-sites
      config.children.each do |sub_config|
        add_configuration(sub_config)
      end
    end

    #
    # registers a page with the site, indexing the page path in our various hashes
    #
    def add_page(page)
      @pages_by_name[page.name] = page
      @pages_by_path[page.path.join('/')] = page
      add_aliases(I18n.default_locale, page, @pages_by_path)
      page.locales.each do |locale|
        next if locale == I18n.default_locale
        add_aliases(locale, page, @pages_by_locale_path[locale])
      end
      @page_list << page
    end

    #
    # registers a page's aliases with the site
    #
    def add_aliases(locale, page, path_hash)
      page.aliases(locale).each do |alias_path|
        alias_path_str = alias_path.join('/')
        if path_hash[alias_path_str]
          Amber.logger.warn "WARNING: page `#{page.path.join('/')}` has alias `#{alias_path_str}`, but this path is already taken by `#{path_hash[alias_path_str].path.join('/')}` (locale = #{locale})."
        else
          path_hash[alias_path_str] = page
        end
      end
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
        hash = {}
        pages_in_path_depth_order.each do |record|
          page = record[:page]
          path = record[:path]
          next if path.length == 1
          path_prefix = path.dup
          path.length.times do |depth|
            path_prefix.shift
            path_str = path_prefix.join('/')
            if @pages_by_path[path_str].nil? && hash[path_str].nil?
              hash[path_str] = page
            end
          end
        end
        # debug:
        #hash.each do |path, record|
        #  puts "#{record[:page].path.join('/')} => #{record[:path].join('/')}"
        #end
        hash
      end
    end

    #
    # Returns an array like this:
    #
    #   [
    #     {:page => <page1>, :path => ['a', 'page1']},
    #     {:page => <page2>, :path => ['a','b', 'page2']},
    #   ]
    #
    # This array is sorted by the depth of the path (shortest first)
    # Pages will appear multiple times (once for each path, including aliases)
    #
    def pages_in_path_depth_order
      paths = {}
      @page_list.each do |page|
        paths[page.path] ||= page
        locales = page.locales
        locales << I18n.default_locale unless locales.include? I18n.default_locale
        locales.each do |locale|
          page.aliases(locale).each do |alias_path|
            paths[alias_path] ||= page
          end
        end
      end
      paths.collect{|path, page| {page:page, path:path}}.sort{|a,b|
        a[:path].length <=> a[:path].length
      }
    end

  end
end