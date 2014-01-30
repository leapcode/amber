#
# All the StaticPage code that deals with rendering
#

require 'i18n'

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
      output_files = []
      view = Render::View.new(self, self.mount_point)
      @mount_point.locales.each do |file_locale|  #content_files.each do |file_locale, content_file|
        content_file = content_file(file_locale)
        next unless content_file
        dest = destination_file(dest_dir, file_locale)
        output_files << dest
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
      asset_files.each do |asset_file|
        src_file = File.join(@file_path, asset_file)
        dst_file = File.join(dest_dir, *@path, asset_file)
        Render::Asset.render(src_file, dst_file)
      end
      output_files
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

  end
end