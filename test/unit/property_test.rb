require File.expand_path('test_helper', File.dirname(__FILE__))

class PropertyTest < Minitest::Test

  class Page
    attr_accessor :parent
    attr_accessor :props
    def initialize
      self.props = Amber::StaticPage::PageProperties.new(self)
    end
    def prop(*args)
      props.prop(*args)
    end
  end

  def setup
    text_en = %(
- @title = 'hi'
- @author = 'you'
- @created_at = 'Sun Aug 12 18:32:20 PDT 2012'
- @color = 'periwinkle'
- @this.local_value = 'robot overlord'
- ignored = 1
)
    text_es = %(
- @title = 'hola'
- @author = 'tu'
- @heading = textile 'h1. hi'
)
    @page_top = Page.new
    @pp = @page_top.props
    @page_bottom = Page.new
    @page_bottom.parent = @page_top

    @pp.eval(text_en, 'en')
    @pp.eval(text_es, 'es')

    I18n.locale = :en
  end

  def test_simple_properties
    assert_equal 'hi', @pp.title
    assert_equal 'you', @pp.author
    assert_nil @pp.ignored
  end

  def test_simple_locale
    assert_equal 'hi', @pp.prop(:en, :title)
    assert_equal 'hola', @pp.prop('es', 'title')
    assert_nil @pp.prop('es', 'ignored')

    I18n.locale = :en
    assert_equal 'hi', @pp.title
    I18n.locale = :es
    assert_equal 'hola', @pp.title
  end

  def test_fallback
    assert_equal 'periwinkle', @pp.prop(:es, :color)
  end

  def test_date
    assert_equal Time.parse('Sun Aug 12 18:32:20 PDT 2012'), @pp.prop(:es, 'created_at')
  end

  def test_textile
    assert_equal "<h1>hi</h1>", @pp.prop('es', :heading)
  end

  def test_local_property
    assert_equal 'robot overlord', @pp.local_value
    assert_equal 'robot overlord', @page_top.prop(:en, :local_value)
    assert_nil @page_bottom.prop(:en, :local_value)
  end

  def test_inheritance
    assert_equal 'periwinkle', @page_bottom.prop(:en, :color)
  end

end
