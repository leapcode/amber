require File.expand_path('test_helper', File.dirname(__FILE__))

class TocTest < Minitest::Test

  def setup
    @texts ||= load_yaml_docs 'toc.yml'
  end

  def test_texts
    @texts.each do |name, test|
      if test['enabled']
        in_html = RedCloth.new(test['in']).to_html
        options = Hash[(test['options']||{}).map{|k,v| [k.to_sym,v]}] # convert keys to use symbols
        regex_toc    = (Amber::Render::RegexTableOfContents.new(in_html, options) if test['backend'] != 'nokogiri')
        nokogiri_toc = (Amber::Render::NokogiriTableOfContents.new(in_html, options) if test['backend'] != 'regex')
        [regex_toc, nokogiri_toc].compact.each do |toc|
          if test['style'] == 'toc'
            html = toc.to_toc
          elsif test['style'] == 'both'
            html = toc.to_toc + "\n" + toc.to_html
          else
            html = toc.to_html
          end
          assert_equal test['out'], html, "toc test `#{name}` failed (using #{toc.class.name})"
        end
      end
    end
  end

end
