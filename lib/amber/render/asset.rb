#
# For rendering things that are assets, like sass files.
# Maybe images too?
#

require 'sass'

module Amber
  module Render
    class Asset

      RENDER_MAP = {
        '.sass' => {:method => 'render_sass', :new_suffix => '.css', :args => [:sass]},
        '.scss' => {:method => 'render_sass', :new_suffix => '.css', :args => [:scss]}
      }

      SOURCE_MAP = {
        '.css' => ['.sass', '.scss']
      }

      def self.render(src_file, dst_file)
        unless Dir.exist?(File.dirname(dst_file))
          FileUtils.mkdir_p(File.dirname(dst_file))
        end
        File.unlink(dst_file) if File.exist?(dst_file)
        src_ext = File.extname(src_file)
        renderer = RENDER_MAP[src_ext]
        if renderer
          content = self.send(renderer[:method], *([src_file] + renderer[:args]))
          new_dst_file = dst_file.sub(/#{Regexp.escape(src_ext)}$/, renderer[:new_suffix])
          File.open(new_dst_file,'w') do |w|
            w.write(content)
          end
        elsif File.basename(src_file) == '.htaccess'
          # existing htaccess file must be copied, not linked, since
          # the render will change its contents.
          FileUtils.cp(src_file, dst_file)
        else
          File.link(src_file, dst_file)
        end
      rescue SystemCallError => exc
        Amber.log_exception(exc)
      end

      #
      # Render assets in a single directory (does not walk
      # directory tree). Files prefixed with an _ are treated
      # as partials and not rendered.
      #
      def self.render_dir(src_dir, dst_dir)
        Dir.chdir(src_dir) do
          Dir.glob('*').each do |file|
            if File.directory?(file) ||
              file =~ /^\./ ||
              file =~ /^_/
              next
            end
            src_file = File.join(src_dir, file)
            dst_file = File.join(dst_dir, file)
            render(src_file, dst_file)
          end
        end
      end

      def self.render_sass(src_file, syntax)
        engine = Sass::Engine.new(
          File.read(src_file),
          :syntax => syntax,
          :load_paths => [File.dirname(src_file)],
          :style => self.sass_render_style
        )
        engine.render
      end

      def self.sass_render_style
        Amber::env == :production ? :compact : :nested
      end

    end
  end
end
