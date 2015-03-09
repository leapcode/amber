require File.expand_path('test_helper', File.dirname(__FILE__))

require 'net/http'

class ApacheTest < Minitest::Test

  APACHE_URL = 'http://127.0.0.1:8888'

  def self.test_order
    :alpha
  end

  def test_001_start_apache
    $path_prefix = nil
    Amber::CLI.new(test_site).rebuild({})
    start_apache(apache_config)
  end

  def test_010_root
    assert_get('/', 'en root')
    assert_get('/en', 'en root')
    assert_get('/de', 'de root')
    assert_get('/en/', 'location:/en')
    assert_get('/de/', 'location:/de')
  end

  def test_011_directory_page
    assert_get('/aaa', 'en aaa')
    assert_get('/en/aaa', 'en aaa')
    assert_get('/de/aaa', 'de aaa')

    assert_get('/aaa/', 'location:/aaa')
    assert_get('/en/aaa/', 'location:/en/aaa')
    assert_get('/de/aaa/', 'location:/de/aaa')
  end

  def test_012_sub_directory_page
    assert_get('/bbb/ccc', 'en ccc')
    assert_get('/en/bbb/ccc', 'en ccc')
    assert_get('/de/bbb/ccc', 'de ccc')

    assert_get('/bbb/ccc/', 'location:/bbb/ccc')
    assert_get('/en/bbb/ccc/', 'location:/en/bbb/ccc')
    assert_get('/de/bbb/ccc/', 'location:/de/bbb/ccc')
  end

  def test_013_file_page
    assert_get('/bbb/ddd', 'ddd')
    assert_get('/en/bbb/ddd', 'ddd')
    assert_get('/de/bbb/ddd', 'ddd')
    assert_get('/fff', 'en fff')
    assert_get('/en/fff', 'en fff')
    assert_get('/de/fff', 'de fff')

    assert_get('/bbb/ddd/', 'location:/bbb/ddd')
    assert_get('/en/bbb/ddd/', 'location:/en/bbb/ddd')
    assert_get('/de/bbb/ddd/', 'location:/de/bbb/ddd')
    assert_get('/fff/', 'location:/fff')
    assert_get('/en/fff/', 'location:/en/fff')
    assert_get('/de/fff/', 'location:/de/fff')
  end

  def test_014_assets
    assert_get('/aaa/asset.css', 'asset')
    assert_get('/en/aaa/asset.css', 'location:/aaa/asset.css')
    assert_get('/de/aaa/asset.css', 'location:/aaa/asset.css')
  end

  def test_099_stop_apache
    stop_apache(apache_config)
  end

  def test_100_start_apache
    $path_prefix = '/test'
    Amber::CLI.new(test_site).rebuild({})
    start_apache(apache_config_with_prefix)
  end

  def test_110_prefix_root
    assert_get('/test', 'en root')
    assert_get('/en/test', 'en root')
    assert_get('/de/test', 'de root')

    assert_get('/test/', 'location:/test')
    assert_get('/en/test/', 'location:/en/test')
    assert_get('/de/test/', 'location:/de/test')
  end

  def test_111_prefix_directory_page
    assert_get('/test/aaa', 'en aaa')
    assert_get('/en/test/aaa', 'en aaa')
    assert_get('/de/test/aaa', 'de aaa')

    assert_get('/test/aaa/', 'location:/test/aaa')
    assert_get('/en/test/aaa/', 'location:/en/test/aaa')
    assert_get('/de/test/aaa/', 'location:/de/test/aaa')
  end

  def test_112_prefix_sub_directory_page
    assert_get('/test/bbb/ccc', 'en ccc')
    assert_get('/en/test/bbb/ccc', 'en ccc')
    assert_get('/de/test/bbb/ccc', 'de ccc')

    assert_get('/test/bbb/ccc/', 'location:/test/bbb/ccc')
    assert_get('/en/test/bbb/ccc/', 'location:/en/test/bbb/ccc')
    assert_get('/de/test/bbb/ccc/', 'location:/de/test/bbb/ccc')
  end

  def test_113_prefix_file_page
    assert_get('/test/bbb/ddd', 'ddd')
    assert_get('/en/test/bbb/ddd', 'ddd')
    assert_get('/de/test/bbb/ddd', 'ddd')
    assert_get('/test/fff', 'en fff')
    assert_get('/en/test/fff', 'en fff')
    assert_get('/de/test/fff', 'de fff')

    assert_get('/test/bbb/ddd/', 'location:/test/bbb/ddd')
    assert_get('/en/test/bbb/ddd/', 'location:/en/test/bbb/ddd')
    assert_get('/de/test/bbb/ddd/', 'location:/de/test/bbb/ddd')
    assert_get('/test/fff/', 'location:/test/fff')
    assert_get('/en/test/fff/', 'location:/en/test/fff')
    assert_get('/de/test/fff/', 'location:/de/test/fff')
  end

  def test_114_assets
    assert_get('/test/aaa/asset.css', 'asset')
    assert_get('/en/test/aaa/asset.css', 'location:/aaa/asset.css')
    assert_get('/de/test/aaa/asset.css', 'location:/aaa/asset.css')
  end

  def test_199_stop_apache
    stop_apache(apache_config_with_prefix)
  end

  private

  def assert_get(path, response_text, status=nil)
    uri = URI(APACHE_URL + path)
    response = Net::HTTP.get_response(uri)
    if response_text =~ /^location:(.*)/
      assert response.header['location'], "for path `#{path}`, location header should be set (was #{response.code}: #{response.body})"
      assert_equal $1, response.header['location'].sub(APACHE_URL, ''), "bad redirect from `#{path}`"
      status ||= 307
    else
      body = response.body.gsub(/<\/?p>\n?/, '')
      assert_equal response_text, body, "unexpected result for `#{path}`"
      status ||= 200
    end
    assert_equal status.to_s, response.code, 'http status code did not match'
  end

  #def get(path)
  #  response = Net::HTTP.get_response('127.0.0.1:8888', path)
  #  if block_given?
  #    yield response
  #  else
  #    response.body
  #  end
  #end

  def apache_config
    File.expand_path('../site/apache.conf', File.dirname(__FILE__))
  end

  def apache_config_with_prefix
    File.expand_path('../site/apache_with_prefix.conf', File.dirname(__FILE__))
  end

  def test_site
    File.expand_path('../site/', File.dirname(__FILE__))
  end

  def start_apache(config)
    `apache2 -f '#{config}' -k stop`
    output = `apache2 -f '#{config}' -k start`
    assert_equal 0, $?, output
  end

  def stop_apache(config)
    output = `apache2 -f '#{config}' -k stop`
    assert_equal 0, $?, output
  end

end
