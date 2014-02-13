# encoding: utf-8

require 'nokogiri'
require 'cgi'

#
# Generates a table of contents for any HTML markup, and adds anchors to headings.
#

module Amber::Render

  ##
  ## TABLE OF CONTENTS
  ##

  class TableOfContents
    #
    # options:
    #   :content_selector (css selector for headings, nokogiri backend only)
    #   :href_base -- use this href for the toc links
    #   :numeric_prefix  -- prefix toc entries and headings with numeric counter (e.g. 1.1.0, 1.2.0, ...)
    #
    def initialize(html, options = {})
      @html = html
      @toc = TocItem.new
      @levels = {"h1" => 0, "h2" => 0, "h3" => 0, "h4" => 0}
      @heading_anchors = {}
      @options = options
      @options[:tag] ||= 'ol'
    end

    def to_html
      parse_doc unless @parsed
      # override this!
    end

    def to_toc
      parse_doc unless @parsed
      # override this!
    end

    private

    def parse_doc
      each_heading(@html) do |heading, heading_text|
        heading_anchor = anchor_text(heading_text)
        heading_text   = strip_anchors(heading_text)
        if @options[:numeric_prefix]
          increment_level(heading)
          heading_text = level_text + " " + heading_text
        end
        @toc.add_heading(heading, heading_text, heading_anchor)
        '<a name="%s"></a>%s' % [heading_anchor, heading_text]
      end
      @parsed = true
    end

    #
    # returns anchor text from heading text.
    # e.g. First Heading! => first-heading
    #
    # if there are duplicates, they get numbered:
    #   heading => heading
    #   heading => heading-2
    #   heading => heading-3
    #
    def anchor_text(heading_text)
      text = nameize(strip_html_tags(heading_text))
      text_with_suffix = text
      i = 2
      while @heading_anchors[text_with_suffix]
        text_with_suffix = "#{text}-#{i}"
        i+=1
      end
      @heading_anchors[text_with_suffix] = true
      text_with_suffix
    end

    #
    # convert any string to one suitable for a url.
    # resist the urge to translit non-ascii slugs to ascii.
    # it is always much better to keep strings as utf8.
    #
    def nameize(str)
      str = str.dup
      str.gsub!(/&(\w{2,6}?|#[0-9A-Fa-f]{2,6});/,'') # remove html entitities
      str.gsub!(/[^- [[:word:]]]/u, '') # remove non-word characters (using unicode definition of a word char)
      str.strip!
      str.downcase!          # upper case characters in urls are confusing
      str.gsub!(/\ +/u, '-') # spaces to dashes, preferred separator char everywhere
      CGI.escape(str)
    end

    # removes all html markup
    def strip_html_tags(html)
      Nokogiri::HTML::DocumentFragment.parse(html, 'UTF-8').children.collect{|child| child.inner_text}.join
    end

    # remove <a name='x'></a> from html, but leaves all other tags in place.
    def strip_anchors(html)
      Nokogiri::HTML::DocumentFragment.parse(html, 'UTF-8').children.collect{|child|
        if child.name == "text"
          child.inner_text
        elsif child.name != 'a' || !child.attributes.detect{|atr| atr[0] == 'name'}
          child.to_s
        end
      }.join
    end

    #
    # prefix headings with text like 1.2.1, if :numeric_prefix => true
    #
    def level_text
      [@levels["h1"], @levels["h2"], @levels["h3"], @levels["h4"]].join(".").gsub(/\.0/, "")
    end

    #
    # keeps a counter of the latest heading at each level
    #
    def increment_level(heading)
      @levels[heading] += 1
      @levels["h2"] = 0 if heading == "h1"
      @levels["h3"] = 0 if heading == "h1" || heading == "h2"
      @levels["h4"] = 0 if heading == "h1" || heading == "h2" || heading == "h3"
    end

    def each_heading(html, &block)
      raise 'override me'
    end
  end

  ##
  ## NOKOGIRI TOC
  ##

  class NokogiriTableOfContents < TableOfContents
    def to_html
      super
      @nokogiri_doc.to_html.gsub(/(<h\d.*?>)\n/, '\1').gsub(/\n(<\/h\d.*?>)/, '\1')
    end

    def to_toc
      super
      ul = Nokogiri::XML::Node.new(@options[:tag], Nokogiri::HTML.fragment(""))
      @toc.populate_node(ul, @options)
      ul.to_pretty_html
    end

    private

    def each_heading(html, &block)
      @nokogiri_doc = Nokogiri::HTML.fragment(html, "UTF-8")
      if @options[:content_selector]
        selector = @levels.keys.map {|h| "#{@options[:content_selector]} #{h}" }.join(",")
      else
        selector = @levels.keys.join(",")
      end
      @nokogiri_doc.css(selector).each do |node|
        node.inner_html = yield(node.name, node.inner_html)
      end
    end
  end

  ##
  ## REGEX TOC
  ##

  class RegexTableOfContents < TableOfContents
    def to_html
      super
      @new_html
    end

    def to_toc
      super
      @toc.to_html(@options)
    end

    private

    HEADING_EX = %r{
      <\s*((h\d).*?)\s*>   # match starting <h1>
        (.+)?              # match innner text
      <\s*\/\2\s*>         # match closing </h1>
    }x

    def each_heading(html, &block)
      @new_html = html.gsub(HEADING_EX) do |match|
        "<%s>%s</%s>" % [$1, yield($2, $3), $2]
      end
    end
  end

  ##
  ## TOC ITEM
  ##
  ## A tree of TocItems composes the table of contents outline.
  ##

  class TocItem
    attr_reader :children, :level, :text, :anchor

    def initialize(heading='h0', text=nil, anchor=nil)
      @level    = heading[1].to_i if heading.is_a?(String)
      @text     = text
      @anchor   = anchor
      @children = []
    end

    def add_heading(heading, heading_text, heading_anchor)
      self.parent_for(heading).children << TocItem.new(heading, heading_text, heading_anchor)
    end

    #
    # generates nokogiri html node tree from this toc
    #
    def populate_node(node, options)
      @children.each do |item|
        li = node.document.create_element("li")
        li.add_child(li.document.create_element("a", item.text, :href => "#{options[:href_base]}##{item.anchor}"))
        if item.children.any?
          ul = li.document.create_element(options[:tag])
          item.populate_node(ul, options)
          li.add_child(ul)
        end
        node.add_child(li)
      end
    end

    #
    # generates html string from this toc
    #
    def to_html(options={})
      html   = []
      tag    = options[:tag]
      indent = options[:indent] || 0
      str    = options[:indent_str] || "  "
      html << '%s<%s>' % [(str*indent), tag]
      @children.each do |item|
        html << '%s<li>' % (str*(indent+1))
        html << '%s<a href="%s#%s">%s</a>' % [str*(indent+2), options[:href_base], item.anchor, item.text]
        if item.children.any?
          html << item.to_html({
            :indent => indent+2,
            :indent_str => str,
            :tag => tag,
            :href_base => options[:href_base]
          })
        end
        html << '%s</li>' % (str*(indent+1))
      end
      html << '%s</%s>' % [(str*indent), tag]
      html.join("\n")
    end

    #
    # Returns the appropriate TocItem for appending a new item
    # at a particular heading level.
    #
    def parent_for(heading)
      heading = heading[1].to_i if heading.is_a?(String)
      if children.any? && children.last.level < heading
        children.last.parent_for(heading)
      else
        self
      end
    end
  end

end

class Nokogiri::XML::Node
  def to_pretty_html(indent=0)
    indent_str = "  " * indent
    children_html = []
    text_html = nil
    if children.size == 1 && children.first.name == "text"
      text_html = children.first.content
    else
      children.each do |child|
        if child.name == "text"
          children_html << "#{"  " * (indent+1)}#{child.content}" if !child.content.empty?
        else
          children_html << child.to_pretty_html(indent+1)
        end
      end
    end
    attrs = []
    attributes.each do |attribute|
      attrs << %(#{attribute[0]}="#{attribute[1]}")
    end
    if attrs.any?
      attr_html = " " + attrs.join(' ')
    else
      attr_html = ""
    end
    html = []
    if text_html
      html << "#{indent_str}<#{name}#{attr_html}>#{text_html}</#{name}>"
    elsif children_html.any?
      html << "#{indent_str}<#{name}#{attr_html}>"
      html += children_html
      html << "#{indent_str}</#{name}>"
    else
      html << "#{indent_str}<#{name}#{attr_html}></#{name}>"
    end
    html.join("\n")
  end
end


=begin

AN ATTEMPT TO GET NOKOGIRI TO OUTPUT REASONABLE HTML5. NO LUCK.

    #
    # convert a Nokogiri::HTML::Document into well formatted html.
    # unfortunately, Nokogiri formatting only works on complete documents, so we strip away the <html> tags. :(
    #
    def format_doc(doc)
      INDENT_XSLT.apply_to(doc).to_s.sub("<!DOCTYPE html>\n<html><body>", '').sub('</body></html>', '')
    end

    # from https://github.com/jarijokinen/html5-beautifier/blob/master/lib/html5-beautifier/xslt/html5-beautifier.xslt
    # MIT License
    INDENT_XSLT_STRING = <<EOF
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="html" omit-xml-declaration="yes" encoding="utf-8" />
  <xsl:param name="indent-increment" select="'__INDENT_STRING__'" />

  <xsl:template name="newline">
    <xsl:text disable-output-escaping="yes">
</xsl:text>
  </xsl:template>

  <xsl:template match="/">
    <xsl:text disable-output-escaping="yes">&lt;!DOCTYPE html></xsl:text>
    <xsl:apply-templates />
  </xsl:template>

  <xsl:template match="comment() | processing-instruction()">
    <xsl:param name="indent" select="''" />
    <xsl:call-template name="newline" />
    <xsl:value-of select="$indent" />
    <xsl:copy />
  </xsl:template>

  <xsl:template match="text()">
    <xsl:param name="indent" select="''" />
    <xsl:call-template name="newline" />
    <xsl:value-of select="$indent" />
    <xsl:value-of select="normalize-space(.)" />
  </xsl:template>

  <xsl:template match="text()[normalize-space(.)='']" />

  <xsl:template match="*">
    <xsl:param name="indent" select="''" />
    <xsl:call-template name="newline" />
    <xsl:value-of select="$indent" />
    <xsl:choose>
      <xsl:when test="count(child::*) > 0 and __EXCLUDE_ELEMENTS__">
        <xsl:copy>
          <xsl:copy-of select="@*" />
          <xsl:apply-templates select="*|text()">
            <xsl:with-param name="indent" select="concat($indent, $indent-increment)" />
          </xsl:apply-templates>
          <xsl:call-template name="newline" />
          <xsl:value-of select="$indent" />
        </xsl:copy>
      </xsl:when>
      <xsl:otherwise>
        <xsl:copy-of select="." />
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
</xsl:stylesheet>
EOF

    INDENT_XSLT = Nokogiri::XSLT(INDENT_XSLT_STRING.gsub('__INDENT_STRING__', '  '))


=end