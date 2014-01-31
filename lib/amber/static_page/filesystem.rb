#
# StaticPage code that interfaces with the filesystem
#

require 'i18n'
require 'pathname'
require 'fileutils'

module Amber
  class StaticPage

    public

    #
    # recursively decends the directory tree, yielding pages and directories it encounters.
    #
    # yield has two arguments:
    #
    # (1) StaticPage instance, or nil.
    # (2) Directory path string if #1 is nil. Path is relative.
    #
    # Directory paths are dirs in the tree that don't contain any pages.
    #
    # this is NOT thread safe
    #
    def self.scan_directory_tree(parent_page, absolute_dir_path, relative_dir_path, &block)
      Dir.chdir(absolute_dir_path) do
        Dir.glob("*").each do |child_path|
          abs_path = File.join(absolute_dir_path, child_path)
          rel_path = File.join(relative_dir_path, child_path)
          if parent_page && is_directory_page?(child_path)
            child_page = StaticPage.new(parent_page, child_path)
            yield child_page, nil
            scan_directory_tree(child_page, abs_path, rel_path, &block)
          elsif parent_page && is_simple_page?(child_path)
            child_page = StaticPage.new(parent_page, child_path)
            yield child_page, nil
          elsif File.directory?(child_path)
            yield nil, rel_path
            scan_directory_tree(nil, abs_path, rel_path, &block)
          end
        end
      end
    end

    #
    # wrap an initial chdir here so that all paths returned for directories are relative.
    #
    def scan_directory_tree(&block)
      #Dir.chdir(self.file_path) do
        StaticPage.scan_directory_tree(self, self.file_path, File.join(self.path), &block)
      #end
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
      if @simple_page
        File.join(dest_dir, "#{File.join(@path)}.#{locale}.html")
      else
        File.join(dest_dir, *@path, "index.#{locale}.html")
      end
    end

    private

    # e.g. en, de, pt
    LOCALES_RE  = /(#{Amber::POSSIBLE_LANGUAGE_CODES.join('|')})/
    LOCALES_GLOB = "{#{Amber::POSSIBLE_LANGUAGE_CODES.join(',')}}"

    # e.g. haml, md, text
    PAGE_SUFFIXES_RE = /(#{Amber::PAGE_SUFFIXES.join('|')})/
    PAGE_SUFFIXES_GLOB = "{#{Amber::PAGE_SUFFIXES.join(',')}}"

    # e.g. en.haml or es.md or index.pt.text
    LOCALE_FILE_MATCH_RE = /^(index\.)?#{LOCALES_RE}\.#{PAGE_SUFFIXES_RE}$/
    LOCALE_FILE_MATCH_GLOB = "{index.,}#{LOCALES_GLOB}.#{PAGE_SUFFIXES_GLOB}"

    #
    # returns true if the name of a file could be a 'simple' static page
    # that is not a directory.
    #
    # rules:
    # * we include files that end in appriopriate suffixes
    # * we exclude file names that are locales.
    # * we exclude partials
    #
    def self.is_simple_page?(name)
      name =~ /\.#{PAGE_SUFFIXES_RE}$/ && name !~ LOCALE_FILE_MATCH_RE && name !~ /^_/
    end

    def self.is_directory_page?(name)
      if File.directory?(name)
        Dir.glob(name + '/' + LOCALE_FILE_MATCH_GLOB).each do |file|
          return true
        end
      end
      return false
    end

    #
    # returns [name, locale, suffix]
    # called on new page initialization
    #
    def parse_source_file_name(name)
      matches = name.match(/^(.*?)(\.#{LOCALES_RE})?(\.#{PAGE_SUFFIXES_RE})$/)
      if matches
        locale = matches[3] ? matches[3].to_sym : nil
        [matches[1], locale, matches[4]]
      else
        [name, nil, nil]
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
          if @locale
            {@locale => [@file_path, ".#{@locale}", @suffix].join}
          else
            {I18n.default_locale => [@file_path, @suffix].join}
          end
        elsif File.directory?(@file_path)
          hsh = {}
          Dir.foreach(@file_path) do |file|
            if file && file =~ LOCALE_FILE_MATCH_RE
              locale = $2
              hsh[locale.to_sym] = File.join(@file_path, file)
            end
          end
          hsh
        end
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
        assets = {}
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
    # this text is extracted and evaluated as ruby to set properties.
    #
    def load_properties
      props = PageProperties.new(self)
      content_files.each do |locale, content_file|
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

    # RAILS
    #def is_haml_template?(locale)
    #  content_file(locale) =~ /\.haml$/
    #  #@suffix == '.haml' || File.exists?(self.absolute_template_path(locale) + '.haml')
    #end

  end
end