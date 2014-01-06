#
# class StaticPage
#
# represents a static website page.
#
#

require 'i18n'
require 'pathname'
require 'RedCloth'
#require 'rbst'
require 'rdiscount'
require 'fileutils'

module Amber
  class StaticPage

    attr_accessor :path,    # array of path segments
      :children,            # array of child pages
      :name,                # the name of the page
      :file_path,           #
      :parent,              # parent page (nil for root page)
      :mount_point,         # associated SiteConfiguration
      :locales,             # currently unused
      :locale,              # if the source page is only in a single locale
      :props                # set of page properties (PropertySet)

    ##
    ## CLASS METHODS
    ##

    def self.find(site, filter)
      if filter =~ /\//
        path = filter.split('/').map{|segment| segment.gsub(/[^0-9a-z_-]/, '')}
        page = site.pages[path.join('/')]
        if page
          return page
        else
          return site.pages[path.last]
        end
      else
        site.pages[filter]
      end
    end

    #
    # loads a directory, creating StaticPages from the directory structure,
    # yielding each StaticPage as it is created.
    #
    def scan(&block)
      Dir.chdir(file_path) do
        Dir.glob("*").each do |child_name|
          if File.directory?(child_name)
            child = StaticPage.new(self, child_name)
            yield child
            child.scan(&block)
          elsif is_simple_page?(child_name)
            child = StaticPage.new(self, child_name)
            yield child
          end
        end
      end
    end

    ##
    ## INSTANCE METHODS
    ##

    def initialize(parent, name, file_path=nil)
      @children = []

      @name, @locale, @suffix = parse_source_file_name(name)

      # set @parent & @path
      if parent
        @parent = parent
        @mount_point = @parent.mount_point
        @parent.add_child(self)
        @path = [@parent.path, @name].flatten.compact
      else
        @path = []
      end

      # set the @file_path
      if file_path
        @file_path = file_path
      elsif @parent && @parent.file_path
        @file_path = File.join(@parent.file_path, @name)
      else
        raise 'file path must be specified or in parent'
      end

      # discover supported locales
      @simple_page = !File.directory?(@file_path)
      #@locales = find_locales()

      # eval the property headers, if any
      @props = load_properties()
    end

    def add_child(page)
      @children << page
    end

    def all_children
      StaticPageArray.new(child_tree.flatten.compact)
    end

    #
    # e.g. /home/user/dev/leap-public-site/app/views/pages/about-us/contact
    #
    #def file_path
    #  "#{@mount_point.directory}/#{@path.join('/')}"
    #end

    #
    # for use with rails, disabled for now.
    # e.g. pages/about-us/contact/en
    #
    def template_path(locale=I18n.locale)
      absolute_template_path(locale)
      #if @simple_page
      #  "#{@mount_point.relative_directory}/#{@path.join('/')}"
      #else
      #  "#{@mount_point.relative_directory}/#{@path.join('/')}/#{locale}"
      #end
    end

    #
    # e.g. pages/about-us/contact/en
    #
    def absolute_template_path(locale=I18n.locale)
      if @simple_page
        "#{@mount_point.pages_dir}/#{@path.join('/')}"
      else
        "#{@mount_point.pages_dir}/#{@path.join('/')}/#{locale}"
      end
    end

    #
    # e.g. pages/about-us/contact/en.haml
    #
    #def source_path(locale=I18n.locale)
    #  if @simple_page
    #
    #  else
    #
    #  end
    #end

    def inspect
      "<'#{@path.join('/')}' #{children.inspect}>"
    end

    #
    # title is tricky
    #
    # * for nav_title, default to title, then try to inherit.
    # * for title, default to nav_title, then try to inherit.
    #
    def title(locale=I18n.locale)
      title = props.get_var_without_inheritance(:title, locale)
      title ||= props.get_var_without_inheritance(:nav_title, locale)
      title ||= props.get_var(:title, locale)
      title ||= props.get_var(:nav_title, locale)
      title ||= I18n.t('pages.'+@name, :raise => false, :default => "Untitled", :locale => locale)
      return title
    end

    def nav_title(locale=I18n.locale)
      return_value = I18n.t('pages.'+@name, :raise => false, :default => "Untitled", :locale => locale)
      if return_value == "Untitled"
        property_title = props.get_var_without_inheritance(:nav_title, locale)
        property_title ||= props.get_var_without_inheritance(:title, locale)
        property_title ||= props.get_var(:nav_title, locale)
        property_title ||= props.get_var(:title, locale)
        property_title ||= return_value
        return_value = property_title
      end
      return_value
    end

    def site_title
      @mount_point.site_title
    end

    #
    # render without layout, possibly with via a rails request
    #
    def render_to_string(renderer=nil)
      begin
        render_locale(renderer, I18n.locale)
      rescue ActionView::MissingTemplate, MissingTemplate => exc
        begin
          render_locale(renderer, I18n.default_locale)
        rescue
          Amber::logger.error "ERROR: could not file template path #{self.template_path}"
          raise exc
        end
      end
    end

    #
    # render a static copy
    #
    # dest_dir - e.g. amber_root/public/
    #
    def render_to_file(dest_dir)
      output_files = []
      content_files.each do |content_file, file_locale|
        file_locale ||= I18n.default_locale
        if @simple_page
          destination_file = File.join(dest_dir, "#{File.join(@path)}.#{file_locale}.html")
        else
          destination_file = File.join(dest_dir, *@path, "index.#{file_locale}.html")
        end
        output_files << destination_file
        unless Dir.exists?(File.dirname(destination_file))
          FileUtils.mkdir_p(File.dirname(destination_file))
        end
        if !File.exist?(destination_file) || File.mtime(content_file) > File.mtime(destination_file)
          File.open(destination_file, 'w') do |f|
            layout = Render::Layout[props.layout || 'default']
            f.write layout.render(self, render_content_file(content_file, file_locale))
          end
        end
      end
      output_files
    end

    def id
      self.name
    end

    #
    # returns a child matching +name+, if any.
    #
    def child(name)
      children.detect {|child| child.name == name}
    end

    protected

    def child_tree
      [self, children.collect{|child| child.child_tree}]
    end

    private

    ##
    ## PROPERTIES
    ##

    #
    # scans the source content files for property headers in the form:
    #
    #    @variable = 'x'
    #    - @variable = 'x'
    #
    # (with or without leading hypen works)
    #
    # this text is extracted and evaluated as ruby to set properties.
    #
    def load_properties
      props = PropertySet.new(self)
      content_files.each do |content_file, locale|
        if File.extname(content_file) == '.haml'
          props.eval(File.read(content_file), locale)
        else
          headers = []
          File.open(content_file) do |f|
            while (line = f.gets) =~ /^(- |)@\w/
              if line !~ /^-/
                line = '- ' + line
              end
              headers << line
            end
          end
          props.eval(headers.join("\n"), locale)
        end
      end
      return props
    end

    ##
    ## CONTENT FILES
    ##

    SUFFIXES = '(haml|md|markdown|txt|textile|rst|latex|pandoc|html)'
    LOCALES  = "(#{Amber::POSSIBLE_LANGUAGE_CODES.join('|')})"
    # e.g. en.haml or es.md
    LOCALE_FILE_MATCH = /^#{LOCALES}\.#{SUFFIXES}$/

    #
    # returns true if the name of a file could be a 'simple' static page
    # with only one translation.
    #
    # rules:
    # * we include files that end in appriopriate suffixes
    # * we exclude file names that are locales.
    #
    def is_simple_page?(name)
      name =~ /\.#{SUFFIXES}$/ && name !~ LOCALE_FILE_MATCH
    end

    #
    # returns [name, locale, suffix]
    #
    def parse_source_file_name(name)
      matches = name.match(/^(.*?)(\.#{LOCALES})?(\.#{SUFFIXES})$/)
      if matches
        locale = matches[3] ? matches[3].to_sym : nil
        [matches[1], locale, matches[4]]
      else
        [name, nil, nil]
      end
    end

    #
    # returns an array like so:
    #
    #  [
    #     ['/path/to/page/en.haml', :en]
    #     ['/path/to/page/es.haml', :es]
    #  ]
    #
    # Or this, if page is simple:
    #
    # [
    #   ['/path/to/page.haml', nil]
    # ]
    #
    #
    def content_files
      if @simple_page
        if @locale
          [[[@file_path, ".#{@locale}", @suffix].join, @locale]]
        else
          [[[@file_path, @suffix].join, nil]]
        end
      elsif File.directory?(@file_path)
        Dir.foreach(@file_path).collect { |file|
          if file && file =~ LOCALE_FILE_MATCH
            [File.join(@file_path, file), $1.to_sym]
          end
        }.compact
      end
    end

    #def self.relative_to_rails_view_root(absolute_path)
    #  if Rails.root
    #    absolute = Pathname.new(absolute_path)
    #    rails_view_root = Pathname.new(Rails.root + 'app/views')
    #    absolute.relative_path_from(rails_view_root).to_s
    #  end
    #end

    ##
    ## RENDERING
    ##

    PROPERTY_HEADER = /^\s*(^(|- )@\w[^\n]*?\n)*/m

    class MissingTemplate < StandardError
    end

    def render_locale(renderer, locale)
      if renderer && is_haml_template?(locale)
        renderer.render_to_string(:template => self.template_path(locale), :layout => false).html_safe
      else
        render_static_locale(locale).html_safe
      end
    end

    def render_static_locale(locale)
      content_files.each do |content_file, file_locale|
        if file_locale.nil? || locale == file_locale
          return render_content_file(content_file, locale)
        end
      end
      raise MissingTemplate.new(template_path(locale))
    end

    def render_content_file(content_file, locale)
      content = File.read(content_file).sub(PROPERTY_HEADER, '')
      suffix = File.extname(content_file)
      if REDCLOTH_FORMATS[suffix]
        render_redcloth(content, suffix, locale)
      elsif RBST_FORMATS[suffix]
        render_rbst(content, suffix, locale)
      elsif RDISCOUNT_FORMATS[suffix]
        render_rdiscount(content, suffix, locale)
      else
        "sorry, i don't understand how to render #{suffix}"
      end
    end

    def is_haml_template?(locale)
      @suffix == '.haml' || File.exists?(self.absolute_template_path(locale) + '.haml')
    end

    RBST_FORMATS = {
      '.rst'      => :rst
    }

    def render_rbst(string, suffix, locale)
      html = RbST.new(string).to_html
      unless (title = explicit_title(locale)).nil?
        html = "<h1 class=\"first\">#{title}</h1>\n\n" + html
      end
      return html
    end

    REDCLOTH_FORMATS = {
      '.txt'      => :textile,
      '.textile'  => :textile
    }

    def render_redcloth(string, suffix, locale)
      unless (title = explicit_title(locale)).nil?
        string = "h1(first). #{title}\n\n" + string
      end
      RedCloth.new(string).to_html
    end

    RDISCOUNT_FORMATS = {
      '.md'      => :markdown,
      '.markdown' => :markdown
    }

    def render_rdiscount(string, suffix, locale)
      rd = RDiscount.new(string, :smart, :generate_toc, :autolink)
      html = rd.to_html
      if props.locale(locale).toc != false && rd.toc_content
        #html = "<div id=\"TOC\">%s</div>\n\n%s" % [rd.toc_content.force_encoding('utf-8'), html]
        html = "<div id=\"TOC\">%s</div>\n\n%s" % [rd.toc_content, html]
      end
      unless (title = explicit_title(locale)).nil?
        html = "<h1 class=\"first\">#{title}</h1>\n\n" + html
      end
      return html
    end

    #
    # returns title iff explicitly set.
    #
    def explicit_title(locale)
      props.get_var_without_inheritance(:title, locale)
    end
  end
end