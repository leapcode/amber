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

    ASSET_RE = /\.(jpg|jpeg|png|gif|webm|css|js|ico)$/

    def initialize(http_server, amber_server)
      @logger = http_server.logger
      @server = amber_server
      super(http_server, @server.site.dest_dir, {:FanyIndexing => true})
    end

    def do_GET(request, response)
      dest_dir = @server.site.dest_dir

      if path_needs_to_be_prefixed?(request.path)
        redirect_with_prefix(request, response)
        return
      end

      path = strip_locale_and_prefix(request.path)
      if File.file?(File.join(dest_dir, request.path))
        @logger.info "Serve static file %s" % File.join(dest_dir, request.path)
        super(request, response)
      elsif File.file?(File.join(dest_dir, path))
        request = request.clone
        request.instance_variable_set(:@path_info, "/"+path)
        @logger.info "Serve static file with locale prefix %s" % File.join(dest_dir, path)
        super(request, response)
      elsif path !~ ASSET_RE
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
          page.render_to_file(dest_dir, :force => true)
          file = page.destination_file(dest_dir, locale)
          if File.exists?(file)
            content = File.read(file)
          else
            file = page.destination_file(dest_dir, I18n.default_locale)
            if File.exists?(file)
              content = File.read(file)
            else
              view = Render::View.new(page, @server.site)
              content = view.render(:text => "No file found at #{file}")
            end
          end
          response.body = content
        end
      else
        super(request, response)
      end
    end
    #rescue Exception => exc
    #  @logger.error exc.to_s
    #  @logger.error exc.backtrace
    #  response.status = 500
    #  response.content_type = 'text/text'
    #  response.body = exc.to_s + "\n\n\n\n" + exc.backtrace

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

  end

end
