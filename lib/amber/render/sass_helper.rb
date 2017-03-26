require 'sass'

module Amber
  module SassFunctions
    def image_url(path)
      Sass::Script::String.new("url(/assets/images/#{path.value})")
    end
  end
end

::Sass::Script::Functions.send :include, Amber::SassFunctions
