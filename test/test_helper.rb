$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__) + '/../lib')

TESTING=true

require 'rubygems'
gem 'minitest'
require 'minitest/autorun'
require 'amber'

class Minitest::Test

  def setup
  end

  def load_yaml_docs(file)
    filepath = File.dirname(__FILE__) + '/files/' + file
    data = {}
    YAML::load_stream(File.open(filepath)) do |doc|
      key = doc.delete("name")
      data[key] = doc
    end
    data
  end

end
