
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

  end
end