#
# A very simple http server for use when previewing pages.
#

require 'webrick'

module Amber
  class Server
    attr_reader :site
    attr_reader :port

    def self.start(options)
      Server.new(options).start
    end

    def initialize(options)
      @site = options[:site]
      @port = options[:port]
      @server = WEBrick::HTTPServer.new :Port => @port, :BindAddress => '127.0.0.1', :DocumentRoot => @site.dest_dir
      @server.mount '/', StaticPageServlet, self
    end

    def start
      trap 'INT' do
        @server.shutdown
      end
      @server.start
    end
  end

  class StaticPageServlet < WEBrick::HTTPServlet::FileHandler

    RENDERABLE_ASSET_RE = /(#{Amber::Render::Asset::SOURCE_MAP.keys.join('|')})$/
    ASSET_RE = /\.(jpg|jpeg|png|gif|webm|css|js|ico)$/

    def initialize(http_server, amber_server)
      @logger = http_server.logger
      @server = amber_server
      super(http_server, @server.site.dest_dir, {:FanyIndexing => true})
    end

    def do_GET(request, response)
      if path_needs_to_be_prefixed?(request.path)
        redirect_with_prefix(request, response)
        return
      end

      path = strip_locale_and_prefix(request.path)

      if renderable_asset?(path)
        @logger.info "Rendering asset file %s" % asset_source_file(path)
        render_asset(path, request, response)
        super(request, response)
      elsif static_file_exists?(request.path)
        @logger.info "Serve static file %s" % static_file_path(request.path)
        super(request, response)
      elsif static_file_exists?(path)
        request = request.clone
        request.instance_variable_set(:@path_info, "/"+path)
        @logger.info "Serve static file with locale prefix %s" % static_file_path(path)
        super(request, response)
      elsif path !~ ASSET_RE
        render_page(path, request, response)
      else
        super(request, response)
      end
    end

    private

    def strip_locale_and_prefix(path)
      # The path comes to the server as URL escaped codes, that are then
      # converty to ascii. But these codes might be utf-8 characters, so we force
      # utf-8 encouding to allows non-ascii paths. I am not sure if always forcing
      # will be a problem.
      path = path.force_encoding('utf-8')
      if @server.site.path_prefix
        path = path.sub(%r{^/?#{Regexp.escape(@server.site.path_prefix)}}, '')
      end
      path.sub(%r{^/?(#{Amber::POSSIBLE_LANGUAGE_CODES.join('|')})(/|$)}, '').sub(%r{/$}, '')
    end

    def get_locale(path)
      match = /\/(#{Amber::POSSIBLE_LANGUAGE_CODES.join('|')})(\/|$)/.match(path)
      if match.nil?
        nil
      else
        match[1]
      end
    end

    def path_needs_to_be_prefixed?(path)
      if @server.site.path_prefix
        path !~ /\.[a-z]{2,4}$/ && (
          path !~ %r{^/?#{Regexp.escape(@server.site.path_prefix)}} ||
          get_locale(path).nil?
        )
      else
        path !~ /\.[a-z]{2,4}$/ && get_locale(path).nil?
      end
    end

    def redirect_with_prefix(request, response)
      path = request.path.gsub(%r{^/|/$}, '')
      location = ["http://localhost:#{@server.port}", @server.site.path_prefix, I18n.default_locale, path].compact.join('/')
      @logger.info "Redirect %s ==> %s" % [request.path, location]
      response.header['Location'] = location
      response.status = 307
    end

    def dst_dir
      @server.site.dest_dir
    end

    def src_dir
      @server.site.pages_dir
    end

    def static_file_exists?(path)
      File.file?(File.join(dst_dir, path))
    end

    def static_file_path(path)
      File.join(dst_dir, path)
    end

    def render_page(path, request, response)
      locale = get_locale(request.path)
      @server.site.load_pages
      page = @server.site.find_page_by_path(path, locale)
      if page
        @logger.info "Serving Page %s" % page.path.join('/')
        response.status = 200
        response.content_type = "text/html; charset=utf-8"
        # always refresh the page we are fetching
        Amber::Render::Layout.reload
        @server.site.render
        page.render_to_file(dst_dir, :force => true)
        file = page.destination_file(dst_dir, locale)
        if File.exists?(file)
          content = File.read(file)
        else
          file = page.destination_file(dst_dir, I18n.default_locale)
          if File.exists?(file)
            content = File.read(file)
          else
            view = Render::View.new(page, @server.site)
            content = view.render(:text => "No file found at #{file}")
          end
        end
        response.body = content
      end
    end

    def renderable_asset?(path)
      path =~ RENDERABLE_ASSET_RE && asset_source_file(path)
    end

    def asset_source_file(path)
      dest_suffix = File.extname(path)
      base_path = path.sub(RENDERABLE_ASSET_RE, '')
      Amber::Render::Asset::SOURCE_MAP[dest_suffix].each do |source_suffix|
        source_file_path = File.join(src_dir, base_path + source_suffix)
        if File.exists?(source_file_path)
          return source_file_path
        end
      end
      return nil
    end

    def render_asset(path, request, response)
      src_file = asset_source_file(path)
      dst_file = [dst_dir, path].join
      Amber::Render::Asset.render(src_file, dst_file)
    end

  end
end
