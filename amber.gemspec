require File.join([File.dirname(__FILE__),'lib','amber','version.rb'])

Gem::Specification.new do |s|
  s.name        = "amber"
  s.version     = Amber::VERSION
  s.summary     = "Static website generator"
  s.description = "Amber is a super simple and super flexible static website generator with support for nice localization and navigation."
  s.authors     = ["Elijah Sparrow"]
  s.email       = ["elijah@leap.se"]
  s.files       = Dir["{lib}/**/*.rb", "{lib}/**/*.erb", "bin/*", "LICENSE", "*.md"]
  s.homepage    = "https://github.com/leapcode/amber"
  s.license     = "AGPL"
  s.executables << 'amber'
  s.bindir      = 'bin'
  s.required_ruby_version = '>= 1.9'

  s.add_runtime_dependency 'i18n', '~> 0.7'
  s.add_runtime_dependency 'haml', '~> 4.0'
  s.add_runtime_dependency 'haml-contrib', '~> 1.0'
  s.add_runtime_dependency 'RedCloth', '~> 4.2'
  s.add_runtime_dependency 'rdiscount', '~> 2.1'
  s.add_runtime_dependency 'nokogiri', '~> 1.6.1'
  s.add_runtime_dependency 'tilt', '>= 2.0.0'
  s.add_runtime_dependency 'sass', '~> 3.2'
end
