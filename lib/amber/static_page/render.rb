#
# All the StaticPage code that deals with rendering
#

require 'i18n'
require 'fileutils'
require 'pathname'

module Amber
  class StaticPage

    #
    # render without layout, possibly with via a rails request
    #
    # RAILS
    # def render_to_string(renderer=nil)
    #   begin
    #     render_locale(renderer, I18n.locale)
    #   rescue ActionView::MissingTemplate, MissingTemplate => exc
    #     begin
    #       render_locale(renderer, I18n.default_locale)
    #     rescue
    #       Amber.logger.error "ERROR: could not file template path #{self.template_path}"
    #       raise exc
    #     end
    #   end
    # end

    #
    # render a static copy
    #
    # dest_dir - e.g. amber_root/public/
    #
    def render_to_file(dest_dir, options={})
      render_content_files(dest_dir, options)
      render_assets(dest_dir)
      if aliases.any?
        link_page_aliases(dest_dir)
      end
    end

    #
    # creates symlinks for aliases to this page.
    # called by Page#render_to_file and Site#render_short_path_aliases
    #
    def link_page_aliases(dest_dir, alias_paths=self.aliases)
      alias_paths.each do |alias_path|
        alias_file_path = Pathname.new(File.join(dest_dir, alias_path))
        page_file_path  = Pathname.new(File.join(dest_dir, *@path))
        symlink(page_file_path, alias_file_path)
      end
    end

    private

    # RAILS
    # def render_locale(renderer, locale)
    #   if renderer && is_haml_template?(locale)
    #     renderer.render_to_string(:template => self.template_path(locale), :layout => false).html_safe
    #   else
    #     render_static_locale(locale).html_safe
    #   end
    # end

    # RAILS
    # def render_static_locale(locale)
    #   content_files.each do |file_locale, content_file|
    #     if locale == file_locale
    #       return Render::View.new(self, self.mount_point).render({file: content_file}, {locale: file_locale})
    #     end
    #   end
    #   raise MissingTemplate.new(template_path(locale))
    # end

    # called only by render_to_file
    def render_assets(dest_dir)
      asset_files.each do |asset_file|
        src_file = File.join(@file_path, asset_file)
        dst_file = File.join(dest_dir, *@path, asset_file)
        Render::Asset.render(src_file, dst_file)
      end
    end

    #
    # create a symlink. arguments must be of type Pathname.
    #
    def symlink(from_path, to_path)
      to_path = realpath(to_path)
      target = from_path.relative_path_from(to_path).to_s.sub(/^\.\.\//, '')
      if !to_path.dirname.directory?
        Amber.logger.warn { "On page `#{@file_path}`, the parent directories for alias name `#{to_path}` don't exist. Skipping alias." }
        return
      end
      if to_path.exist? && to_path.symlink?
        File.unlink(to_path)
      end
      if !to_path.exist?
        Amber.logger.debug { "Symlink #{to_path} => #{target}" }
        FileUtils.ln_s(target, to_path)
      end
    end

    def realpath(pathname)
      dir = pathname.dirname
      if dir.directory? || dir.symlink?
        dir.realpath + pathname.basename
      else
        pathname
      end
    end

    # called only by render_to_file
    def render_content_files(dest_dir, options)
      view = Render::View.new(self, self.mount_point)
      @mount_point.locales.each do |file_locale|
        content_file = content_file(file_locale)
        next unless content_file
        dest = destination_file(dest_dir, file_locale)
        unless Dir.exists?(File.dirname(dest))
          FileUtils.mkdir_p(File.dirname(dest))
        end
        if options[:force] || !File.exist?(dest) || File.mtime(content_file) > File.mtime(dest)
          File.open(dest, 'w') do |f|
            layout = @props.layout || 'default'
            f.write view.render({file: content_file, layout: layout}, {locale: file_locale})
          end
        end
      end
    end

  end
end