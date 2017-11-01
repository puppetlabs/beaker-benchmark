require 'stringify-hash'
require 'beaker-benchmark/helpers'
require 'beaker-benchmark/version'


module Beaker
  module DSL
    module BeakerBenchmark
      include Beaker::DSL::BeakerBenchmark::Helpers
    end
  end
end


# Boilerplate DSL inclusion mechanism:
# First we register our module with the Beaker DSL
Beaker::DSL.register( Beaker::DSL::BeakerBenchmark )
# Modules added into a module which has previously been included are not
# retroactively included in the including class.
#
# https://github.com/adrianomitre/retroactive_module_inclusion
Beaker::TestCase.class_eval { include Beaker::DSL }
