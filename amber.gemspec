Gem::Specification.new do |s|
  s.name        = "amber"
  s.version     = "0.2.5"
  s.summary     = "Static website generator"
  s.description = "Amber is a super simple and super flexible static website generator with support for nice localization and navigation."
  s.authors     = ["Elijah Sparrow"]
  s.email       = ["elijah@riseup.net"]
  s.files       = Dir["{lib}/**/*.rb", "bin/*", "LICENSE", "*.md"]
  s.homepage    = "https://github.com/leapcode/amber"
  s.license     = "AGPL"
  s.executables << 'amber'
  s.bindir      = 'bin'
  s.required_ruby_version = '>= 1.9'

  s.add_runtime_dependency 'i18n'
  s.add_runtime_dependency 'haml'
  s.add_runtime_dependency 'haml-contrib'
  s.add_runtime_dependency 'RedCloth'
  s.add_runtime_dependency 'rdiscount'
  s.add_runtime_dependency 'nokogiri', '~> 1.6.1'
  s.add_runtime_dependency 'tilt', '>= 2.0.0'
  s.add_runtime_dependency 'sass', '~> 3.2'
end
