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
      clear
    end

    def rebuild(options)
      clear
      build
    end

    def server(options)
      site = Site.new(@root)
      Amber::Server.start(:port => (options[:port] || 8000), :site => site)
    end

  end
end