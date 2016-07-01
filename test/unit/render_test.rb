require File.expand_path('test_helper', File.dirname(__FILE__))

class RenderTest < Minitest::Test

  def setup
  end

  def test_bracket_links
    texts = {
      "[[page-name]]" => [nil, 'page-name'],
      " [[ page-name ]] " => [nil, 'page-name'],
      "[[ label => page-name ]]" => ['label', 'page-name'],
      " [[label->page-name]] " => ['label', 'page-name'],
      "x[[page-name]]y" => [nil, 'page-name'],
      "[[ how do I? => carefully ]]" => ['how do I?', 'carefully']
    }
    texts.each do |markup, expected|
      Amber::Render::Filter::Bracketlink.run(markup) do |from, to|
        assert_equal expected, [from, to]
      end
    end
  end

end
