require 'fileutils'

module Amber
  class CLI

    def initialize(root, *args)
      @options = {}
      @options = args.pop if args.last.is_a?(::Hash)
      @root    = File.expand_path(root)
    end

    def init(options)
      new_dir = options[:arg]
      mkdir(new_dir, nil)
      mkdir('amber', new_dir)
      copy_template_file('config.rb', 'amber', new_dir)
      touch('amber/menu.txt', new_dir)
      mkdir('amber/layouts', new_dir)
      mkdir('amber/locales', new_dir)
      mkdir('public', new_dir)
      mkdir('pages', new_dir)
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
      FileUtils.mkdir_p(site.dest_dir) unless File.exist?(site.dest_dir)
      gitkeep = File.exist?(File.join(site.dest_dir, '.gitkeep'))
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
      FileUtils.rm_r(temp_render) if temp_render && File.exist?(temp_render)
      FileUtils.rm_r(temp_old_pages) if temp_old_pages && File.exist?(temp_old_pages)
    end

    def server(options)
      require 'amber/server'
      host = nil
      port = nil
      if options[:arg]
        host, port = options[:arg].split(':')
      end
      if host.nil? || host.empty?
        host = DEFAULT_HOST
      end
      if port.nil? || port.empty?
        port = DEFAULT_PORT
      end
      site = Site.new(@root)
      Amber::Server.start(:port => port, :host => host, :site => site)
    end

    def apache(options)
      site = Site.new(@root)
      directory = options[:arg]
      unless directory
        puts "Missing DIRECTORY argument"
        exit 1
      end
      directory = directory.gsub(%r{^/|/$}, '')
      Amber::Render::Apache.echo_config(site, directory)
    end

    private

    def mkdir(dir, context)
      if context
        path = File.join(context, dir)
        print_path = File.join(File.basename(context), dir)
      else
        path = dir
        print_path = dir
      end
      unless Dir.exist?(path)
        if File.exist?(path)
          puts "Could not make directory `#{print_path}`. File already exists."
          exit(1)
        end
        FileUtils.mkdir_p(path)
        puts "* Creating `#{print_path}`"
      end
    end

    def touch(file, context)
      path = File.join(context, file)
      unless File.exist?(path)
        FileUtils.touch(path)
        puts "* Creating `#{File.basename(context)}/#{file}`"
      end
    end

    def copy_template_file(template_file, destination, context)
      template_file_path = File.dirname(__FILE__) + "/templates/#{template_file}"
      copy(template_file_path, destination, context)
    end

    def copy(source, destination, context)
      destination_path = File.join(context, destination)
      FileUtils.copy(source, destination_path)
      puts "* Creating `#{File.basename(context)}/#{destination}/#{File.basename(source)}`"
    end

  end
end
