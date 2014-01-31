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

    # called only by render_to_file
    # for now, we only support aliases on pages that are directories, for simplicity sake.
    def link_page_aliases(dest_dir)
      if @simple_page
        Amber.logger.warn { "The page `#{@file_path}` sets a path alias, but currently aliases are only supported for directory-based pages. Skipping." }
      else
        aliases.each do |alias_path|
          alias_path = Pathname.new(File.join(dest_dir, alias_path))
          if !File.directory?(File.dirname(alias_path))
            Amber.logger.warn { "On page `#{@file_path}`, the parent directories for alias name `#{alias_path}` don't exist. Skipping alias." }
          else
            page_path = Pathname.new(File.join(dest_dir, *@path))
            target = page_path.relative_path_from(alias_path).to_s.sub(/^\.\.\//, '')
            if File.exists?(alias_path)
              if File.symlink?(alias_path)
                File.unlink(alias_path)
                Amber.logger.debug { "Alias #{alias_path} => #{target}" }
                FileUtils.ln_s(target, alias_path)
              else
                Amber.logger.warn { "The page `#{@file_path}` sets a path alias, but there is already a file in the way (`#{alias_path}`)" }
              end
            else
              Amber.logger.debug { "Alias #{alias_path} => #{target}" }
              FileUtils.ln_s(target, alias_path)
            end
          end
        end
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