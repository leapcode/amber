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

  def load_yaml_docs(file)
    filepath = File.dirname(__FILE__) + '/files/' + file
    data = {}
    YAML::load_documents(File.open(filepath)) do |doc|
      key = doc.delete("name")
      data[key] = doc
    end
    data
  end

end
