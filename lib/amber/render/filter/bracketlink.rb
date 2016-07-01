# encoding: utf-8

#
# bracket links are links in the form [[label => target]] or [[page-name]]
#

module Amber
  module Render
    module Filter
      module Bracketlink

        # linking using double square brackets
        BRACKET_LINK_RE = /
          \[\[          # start [[
          ([^\[\]]+)    # $text : one or more characters that are not [ or ] ($1)
          \]\]          # end ]]
        /x

        def self.run(text, &block)
          text.gsub(BRACKET_LINK_RE) do |m|
            link_text = $~[1].strip
            if link_text =~ /^.+\s*[-=]>\s*.+$/
              # link_text == "from -> to"
              from, to = link_text.split(/\s*[-=]>\s*/)[0..1]
              from = "" unless from.instance_of? String # \ sanity check for
              to   = "" unless from.instance_of? String # / badly formed links
            else
              # link_text == "to" (ie, no link label)
              from = nil
              to = link_text
            end
            yield(from, to)
          end
        end

      end
    end
  end
end