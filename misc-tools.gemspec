# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

Gem::Specification.new do |s|
  s.name        = "misc-tools"
  s.version     = "0.1"
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["JT Olds"]
  s.email       = ["hello@jtolds.com"]
  s.homepage    = "https://github.com/jtolds/misc-tools" 
  s.summary     = "Misc git tools"
  s.description = "Does not work with ruby 2.0 onward (due to grit dependency)."

  s.required_rubygems_version = ">= 1.8.0"

  s.add_dependency "grit", "2.5.0"

  s.files = Dir['lib/**/*.rb'] + Dir['bin/*'] + %w[LICENSE]

  s.executables  = %w[changelog git-treesame-commit git-treesame-find]
  s.require_path = 'lib'
end
