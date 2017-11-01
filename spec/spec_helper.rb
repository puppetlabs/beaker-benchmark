require 'simplecov'
require 'beaker_test_helpers'
require 'beaker-benchmark'
require 'helpers'

require 'rspec/its'

RSpec.configure do |config|
  config.include TestFileHelpers
  config.include HostHelpers
end
