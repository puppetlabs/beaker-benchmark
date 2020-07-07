# -*- encoding: utf-8 -*-
$LOAD_PATH.unshift File.expand_path("../lib", __FILE__)
require 'beaker-benchmark/version'

Gem::Specification.new do |s|
  s.name        = "beaker-benchmark"
  s.version     = Beaker::DSL::BeakerBenchmark::Version::STRING
  s.authors     = ["Puppet"]
  s.email       = ["team-system-level-validation@puppet.com"]
  s.homepage    = "https://github.com/puppetlabs/beaker-benchmark"
  s.summary     = %q{Beaker benchmark Helpers!}
  s.description = %q{Used to monitor performance on a puppet infrastructure node in a Beaker test}
  s.license     = "Apache-2.0"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # Testing dependencies
  s.add_development_dependency 'rspec', '~> 3.0'
  s.add_development_dependency 'rspec-its'
  s.add_development_dependency 'fakefs', '~> 0.6'
  s.add_development_dependency 'rake', '~> 13.0'
  s.add_development_dependency 'simplecov'
  s.add_development_dependency 'pry', '~> 0.10'

  # Documentation dependencies
  s.add_development_dependency 'yard'
  s.add_development_dependency 'markdown'
  s.add_development_dependency 'thin'

  # Run time dependencies
  s.add_runtime_dependency 'stringify-hash', '~> 0.0.0'

end

