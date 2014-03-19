module Amber
  class CLI

    def initialize(root, *args)
      @options = {}
      @options = args.pop if args.last.is_a?(::Hash)
      @root    = File.expand_path(root)
    end

    def init(options)
      puts 'not yet implemented'
    end

    def build(options)
      site = Site.new(@root)
      site.load_pages
      site.render
    end

    def clear(options)
      site = Site.new(@root)
      site.clear
    end

    def clean(options)
      clear(options)
    end

    def rebuild(options)
      site = Site.new(@root)
      site.continue_on_error = false
      site.load_pages
      gitkeep = File.exists?(File.join(site.dest_dir, '.gitkeep'))
      temp_render = File.join(File.dirname(site.dest_dir), 'public-tmp')
      temp_old_pages = File.join(File.dirname(site.dest_dir), 'remove-me')
      site.with_destination(temp_render) do
        site.render
      end
      FileUtils.mv(site.dest_dir, temp_old_pages)
      FileUtils.mv(temp_render, site.dest_dir)
      site.with_destination(temp_old_pages) do
        site.clear
        FileUtils.rm_r(temp_old_pages)
      end
      if gitkeep
        FileUtils.touch(File.join(site.dest_dir, '.gitkeep'))
      end
    ensure
      # cleanup if something goes wrong.
      FileUtils.rm_r(temp_render) if File.exists?(temp_render)
      FileUtils.rm_r(temp_old_pages) if File.exists?(temp_old_pages)
    end

    def server(options)
      site = Site.new(@root)
      Amber::Server.start(:port => (options[:port] || 8000), :site => site)
    end

  end
end