#
# StaticPage code that interfaces with the filesystem
#

require 'i18n'
require 'pathname'
require 'fileutils'
require 'json'
require 'yaml'

module Amber
  class StaticPage

    public

    #
    # Recursively decends the directory tree, yielding pages and directories it encounters.
    #
    # yield has two arguments:
    #
    # (1) StaticPage instance, or nil.
    # (2) Directory path string if #1 is nil. Path is relative.
    #
    # Directory paths are dirs in the tree that don't contain any pages.
    #
    def self.scan_directory_tree(parent_page, absolute_dir_path, relative_dir_path, &block)
      Dir.foreach(absolute_dir_path).each do |child_path|
        next if child_path =~ /^\./
        abs_path = File.join(absolute_dir_path, child_path)
        rel_path = File.join(relative_dir_path, child_path)
        if parent_page && is_directory_page?(abs_path)
          child_page = StaticPage.new(parent_page, child_path)
          if child_page.valid?
            yield child_page, nil
            scan_directory_tree(child_page, abs_path, rel_path, &block)
          end
        elsif parent_page && is_simple_page?(abs_path)
          child_page = StaticPage.new(parent_page, child_path)
          if child_page.valid?
            yield child_page, nil
          end
        elsif File.directory?(abs_path)
          yield nil, rel_path
          scan_directory_tree(nil, abs_path, rel_path, &block)
        end
      end
    end

    def scan_directory_tree(&block)
      StaticPage.scan_directory_tree(self, self.file_path, File.join(self.path), &block)
    end

    #
    # e.g. /home/user/dev/leap-public-site/app/views/pages/about-us/contact
    #
    #def file_path
    #  "#{@mount_point.directory}/#{@path.join('/')}"
    #end

    #
    # e.g. pages/about-us/contact/en
    # RAILS
    #def template_path(locale=I18n.locale)
    #  absolute_template_path(locale)
    #  #if @simple_page
    #  #  "#{@mount_point.relative_directory}/#{@path.join('/')}"
    #  #else
    #  #  "#{@mount_point.relative_directory}/#{@path.join('/')}/#{locale}"
    #  #end
    #end

    #
    # e.g. pages/about-us/contact/en
    # RAILS
    #def absolute_template_path(locale=I18n.locale)
    #  if @simple_page
    #    "#{@mount_point.pages_dir}/#{@path.join('/')}"
    #  else
    #    "#{@mount_point.pages_dir}/#{@path.join('/')}/#{locale}"
    #  end
    #end

    #
    # full filesystem path name of the source content file
    # e.g. /home/user/mysite/pages/about-us/contact/en.md
    #
    def content_file(locale)
      content_files[locale] || content_files[I18n.default_locale] || content_files.values.first
    end

    def content_file_exists?(locale)
      !!content_files[locale]
    end

    #
    # full filesystem path name of the destination rendered file
    # e.g. /home/user/mysite/public/about-us/contact/index.en.html
    #
    def destination_file(dest_dir, locale)
      File.join(dest_dir, *@path, "index.#{locale}.html")
    end

    # e.g. en, de, pt
    LOCALES_RE  = /(?<locale>#{Amber::POSSIBLE_LANGUAGE_CODES.join('|')})/
    LOCALES_GLOB = "{#{Amber::POSSIBLE_LANGUAGE_CODES.join(',')}}"

    # e.g. haml, md, text
    PAGE_SUFFIXES_RE = /(?<suffix>#{Amber::PAGE_SUFFIXES.join('|')})/
    PAGE_SUFFIXES_GLOB = "{#{Amber::PAGE_SUFFIXES.join(',')}}"

    # e.g. json, yaml
    VAR_SUFFIXES_RE = /(?<suffix>#{Amber::VAR_SUFFIXES.join('|')})/
    VAR_SUFFIXES_GLOB = "{#{Amber::VAR_SUFFIXES.join(',')}}"

    # e.g. en.haml or es.md or index.pt.text
    LOCALE_FILE_MATCH_RE = /^(index\.)?#{LOCALES_RE}\.#{PAGE_SUFFIXES_RE}$/
    LOCALE_FILE_MATCH_GLOB = "{index.,}#{LOCALES_GLOB}.#{PAGE_SUFFIXES_GLOB}"

    VAR_FILE_MATCH_RE = /^(index\.)?#{LOCALES_RE}\.#{VAR_SUFFIXES_RE}$/
    VAR_FILE_MATCH_GLOB = "{index.,}#{LOCALES_GLOB}.#{VAR_SUFFIXES_GLOB}"

    SIMPLE_FILE_MATCH_RE = lambda {|name| /^(#{Regexp.escape(name)})(\.#{LOCALES_RE})?\.#{PAGE_SUFFIXES_RE}$/ }
    SIMPLE_VAR_MATCH_RE = lambda {|name| /^(#{Regexp.escape(name)})(\.#{LOCALES_RE})?\.#{VAR_SUFFIXES_RE}$/ }

    private

    #
    # returns true if the name of a file could be a 'simple' static page
    # that is not a directory.
    #
    # rules:
    # * we include files that end in appriopriate suffixes
    # * we exclude file names that are locales.
    # * we exclude partials
    #
    def self.is_simple_page?(absolute_path)
      name = File.basename(absolute_path)
      name =~ /\.#{PAGE_SUFFIXES_RE}$/ && name !~ LOCALE_FILE_MATCH_RE && name !~ /^_/
    end

    def self.is_directory_page?(absolute_path)
      if File.directory?(absolute_path)
        Dir.glob(absolute_path + '/' + LOCALE_FILE_MATCH_GLOB).each do |file|
          return true
        end
      end
      return false
    end

    #
    # returns [name, suffix]
    # called on new page initialization
    #
    def parse_source_file_name(name)
      matches = name.match(/^(?<name>.*?)(\.#{LOCALES_RE})?(\.#{PAGE_SUFFIXES_RE})$/)
      if matches
        [matches['name'], matches['suffix']]
      else
        [name, nil]
      end
    end

    #
    # returns the files that compose the content for this page,
    # a different file for each locale (or no locale)
    #
    # returns a hash like so:
    #
    #  {
    #     :en => '/path/to/page/en.haml',
    #     :es => '/path/to/page/index.es.md'
    #  }
    #
    # Or this, if page is simple:
    #
    # {
    #   :en => '/path/to/page.haml'
    # }
    #
    #
    def content_files
      @content_files ||= begin
        if @simple_page
          directory = File.dirname(@file_path)
          regexp = SIMPLE_FILE_MATCH_RE.call(@name)
        else
          directory = @file_path
          regexp = LOCALE_FILE_MATCH_RE
        end
        hsh = {}
        Dir.foreach(directory) do |file|
          if file && match = regexp.match(file)
            locale = match['locale'] || I18n.default_locale
            hsh[locale.to_sym] = File.join(directory, file)
          end
        end
        hsh
      end
    end

    #
    # returns an array of files in the folder that corresponds to this page
    # that are not other pages. in other words, the assets in this folder
    #
    # file paths are relative to @file_path
    #
    def asset_files
      if @simple_page
        []
      else
        Dir.foreach(@file_path).collect { |file|
          if file && file !~ /\.#{PAGE_SUFFIXES_RE}$/
            file unless File.directory?(File.join(@file_path, file))
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

    #
    # scans the source content files for property headers in the form:
    #
    #    @variable = 'x'
    #    - @variable = 'x'
    #
    # (with or without leading hypen works)
    #
    # This text is extracted and evaluated as ruby to set properties.
    #
    # The first paragraph is loaded into the property "excerpt".
    #
    def load_properties
      props = PageProperties.new(self)
      content_files.each do |locale, content_file|
        if type_from_path(content_file) == :haml
          props.eval(File.read(content_file, :encoding => 'UTF-8'), locale)
        else
          headers, excerpt = parse_headers(content_file)
          props.eval(headers, locale)
          if !excerpt.empty?
            props.set_prop(locale, "excerpt", excerpt)
          end
          props.set_prop(locale, "content_type", type_from_path(content_file))
        end
        cleanup_properties(props, locale)
      end
      unless props.prop_without_inheritance(I18n.default_locale, :name)
        props.set_prop(I18n.default_locale, :name, self.name)
      end
      return props
    end

    def cleanup_properties(props, locale)
      if props.prop(locale, :alias)
        props.set_prop(locale, :alias, [props.prop(locale, :alias)].flatten)
      end
    end

    #
    # parses a content_file's property headers and tries to extract the
    # first paragraph.
    #
    def parse_headers(content_file)
      headers = []
      para1 = []
      para2 = []
      file_type = type_from_path(content_file)

      File.open(content_file, :encoding => 'UTF-8') do |f|
        while (line = f.gets) =~ /^(- |)@\w/
          if line !~ /^-/
            line = '- ' + line
          end
          headers << line
        end
        # eat empty lines
        while line = f.gets
          break unless line =~ /^\s*$/
        end
        # grab first two paragraphs
        para1 << line
        while line = f.gets
          break if line =~ /^\s*$/
          para1 << line
        end
        while line = f.gets
          break if line =~ /^\s*$/
          para2 << line
        end
      end

      headers = headers.join
      para1 = para1.join
      para2 = para2.join
      excerpt = ""

      # pick the first non-heading paragraph.
      # this is stupid, and chokes on nested headings.
      # but is also cheap and fast :)
      if file_type == :textile
        if para1 =~ /^h[1-5]\. /
          excerpt = para2
        else
          excerpt = para1
        end
      elsif file_type == :markdown
        if para1 =~ /^#+ / || para1 =~ /^(===+|---+)\s*$/m
          excerpt = para2
        else
          excerpt = para1
        end
      end
      return [headers, excerpt]
    end

    ##
    ## VARIABLES
    ## Variables are associated with a page, but unlike properties they are not
    ## inheritable. Variables are defined in a separate file.
    ##
    def variable_files
      if @simple_page
        directory = File.dirname(@file_path)
        regexp = SIMPLE_VAR_MATCH_RE.call(@name)
      else
        directory = @file_path
        regexp = VAR_FILE_MATCH_RE
      end
      hsh = {}
      Dir.foreach(directory) do |file|
        if file && match = regexp.match(file)
          locale = match['locale'] || I18n.default_locale
          hsh[locale.to_sym] = File.join(directory, file)
        end
      end
      hsh
    end

    def load_variables
      vars = {}
      variable_files.each do |locale, var_file|
        begin
          if var_file =~ /\.ya?ml$/
            vars[locale] = YAML.load_file(var_file)
          elsif var_file =~ /\.json$/
            vars[locale] = JSON.parse(File.read(var_file))
          end
        rescue StandardError => exc
          Amber.logger.error('ERROR: could not load file #{var_file}: ' + exc.to_s)
        end
      end
      return vars
    end

    def type_from_path(path)
      case File.extname(path)
      when ".text", ".textile"
        :textile
      when ".md", ".markdown"
        :markdown
      when ".haml"
        :haml
      when ".html"
        :html
      when ".erb"
        :erb
      else
        :unknown
      end
    end

    # RAILS
    #def is_haml_template?(locale)
    #  content_file(locale) =~ /\.haml$/
    #  #@suffix == '.haml' || File.exist?(self.absolute_template_path(locale) + '.haml')
    #end

  end
end