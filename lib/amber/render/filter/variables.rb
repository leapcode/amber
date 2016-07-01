# encoding: utf-8

#
# bracket links are links in the form [[label => target]] or [[page-name]]
#

module Amber
  module Render
    module Filter
      module Variables

        # variable expansion uses {{ }}
        VARIABLES_RE = /
          \{\{          # start {{
          ([^\{\}]+)    # $text : one or more characters that are not { or } ($1)
          \}\}          # end }}
        /x

        def self.run(text, &block)
          text.gsub(VARIABLES_RE) do |m|
            variable_name = $~[1].strip
            yield(variable_name)
          end
        end

      end
    end
  end
end