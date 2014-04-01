module Amber
  module Render
    class Apache

      def self.write_htaccess(site, directory)
        htaccess_file = File.join(directory, '.htaccess')
        template = Tilt::ERBTemplate.new(template_path("htaccess.erb"))
        File.open(htaccess_file, 'w', :encoding => 'UTF-8') do |f|
          f.write template.render(context_object(:site => site))
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
