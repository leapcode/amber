$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__) + '/../lib')

require 'rubygems'
gem 'minitest'
require 'minitest/autorun'
require 'webmock/minitest'
require 'amber'

TESTING=true

class Minitest::Test

  def setup
  end

end
