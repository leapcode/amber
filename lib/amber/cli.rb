
module Amber
  class CLI
    def initialize(root, *args)
      @options = {}
      @options = args.pop if args.last.is_a?(::Hash)
      @root    = File.expand_path(root)
    end

    def init
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

  end
end