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

    def initialize(http_server, amber_server)
      @logger = http_server.logger
      @server = amber_server
      super(http_server, @server.site.dest_dir, {:FanyIndexing => true})
    end

    def do_GET(request, response)
      dest_dir = @server.site.dest_dir

      # add local prefix for all paths that don't have a file suffix
      if request.path !~ /\.[a-z]{2,4}$/
        locale = get_locale(request)
        if !locale
          location = "http://localhost:#{@server.port}/#{I18n.default_locale}#{request.path.sub(/\/$/,'')}"
          @logger.info "Redirect %s ==> %s" % [request.path, location]
          response.header['Location'] = location
          response.status = 307
          return
        end
      end

      if File.exists?(File.join(dest_dir, request.path))
        @logger.info "Serve static file %s" % File.join(dest_dir, request.path)
        super(request, response)
      else
        path = strip_locale(request.path)
        @server.site.load_pages
        page = @server.site.find_page_by_path(path)
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
        else
          request = request.clone
          request.instance_variable_set(:@path_info, "/" + strip_locale(request.path_info))
          @logger.info "Serve static file %s" % File.join(dest_dir, request.path_info)
          super(request, response)
        end
      end
    end
    #rescue Exception => exc
    #  @logger.error exc.to_s
    #  @logger.error exc.backtrace
    #  response.status = 500
    #  response.content_type = 'text/text'
    #  response.body = exc.to_s + "\n\n\n\n" + exc.backtrace

    private

    def strip_locale(path)
      path.sub(/^\/(#{Amber::POSSIBLE_LANGUAGE_CODES.join('|')})(\/|$)/, '').sub(/\/$/, '')
    end

    def get_locale(request)
      match = /\/(#{Amber::POSSIBLE_LANGUAGE_CODES.join('|')})(\/|$)/.match(request.path)
      if match.nil?
        nil
      else
        match[1]
      end
    end
  end

end
