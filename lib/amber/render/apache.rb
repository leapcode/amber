module Amber
  module Render
    class Apache

      def self.write_htaccess(site, src_dir, dst_dir)
        src_htaccess_file = File.join(src_dir, '.htaccess')
        dst_htaccess_file = File.join(dst_dir, '.htaccess')
        template = Tilt::ERBTemplate.new(template_path("htaccess.erb"))

        tail_content = nil
        if File.exist?(src_htaccess_file)
          tail_content = File.read(src_htaccess_file)
        end
        File.open(dst_htaccess_file, 'w', :encoding => 'UTF-8') do |f|
          f.write template.render(context_object(:site => site))
          if tail_content
            f.write "\n\n"
            f.write tail_content
          end
        end
      end

      def self.echo_config(site, directory)
        template = Tilt::ERBTemplate.new(
          site.path_prefix ? template_path('apache_config_with_prefix.erb') : template_path('apache_config.erb')
        )
        puts template.render(context_object(:site => site, :directory => directory))
      end

      def self.context_object(variables)
        object = Object.new
        variables.each do |name, value|
          object.instance_variable_set("@#{name}", value)
        end
        object
      end

      def self.template_path(filename)
        File.expand_path("../templates/#{filename}", File.dirname(__FILE__))
      end

    end
  end
end
