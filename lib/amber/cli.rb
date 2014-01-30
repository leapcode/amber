module Amber
  class CLI

    def initialize(root, *args)
      @options = {}
      @options = args.pop if args.last.is_a?(::Hash)
      @root    = File.expand_path(root)
    end

    def init
      puts 'not yet implemented'
    end

    def build
      site = Site.new(@root)
      site.load_pages
      site.render
    end

    def clear
      site = Site.new(@root)
      site.clear
    end

    def clean
      clear
    end

    def rebuild
      clear
      build
    end

    def server
      site = Site.new(@root)
      Amber::Server.start(:port => 8000, :site => site)
    end

  end
end