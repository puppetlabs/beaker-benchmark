require 'spec_helper'

class ClassMixedWithDSLHelpers
  include BeakerTestHelpers
  include Beaker::DSL::BeakerBenchmark::Helpers

  def logger
    RSpec::Mocks::Double.new('logger').as_null_object
  end

end

describe ClassMixedWithDSLHelpers do
  subject { ClassMixedWithDSLHelpers.new }

  describe 'release conditions' do

    it 'has updated the version number from the original template' do
      expect( Beaker::DSL::BeakerBenchmark::Version::STRING ).to_not be === '0.0.1rc0'
    end

    it 'has a MAINTAINERS doc' do
      expect( File.exist?( 'MAINTAINERS' ) ).to be_truthy
    end

  end

  describe '.setup_atop' do

    it 'installs atop on first run' do

    end

    it 'sets up epel repo on el hosts on first run' do

    end

    it 'does not install atop after first run' do

    end




  end

  describe '.measure_perf_on' do

    it 'concatenates test name with action name if available' do

    end

    it 'only uses action name if test name is not available' do

    end

  end

  describe '.start_monitoring' do

    it 'executes atop command' do

    end

    it 'executes atop command with additional arguments if include_processes=true' do

    end

    it 'sets appropriate value for @beaker_benchmark_start' do

    end

  end

  describe '.stop_monitoring' do

    it 'sets duration, if @beaker_benchmark_start has a value' do

    end

    it 'defaults duration to 0, if @beaker_benchmark_start has no value' do

    end

    it 'kills the background atop process' do

    end


  end

  describe '.set_processes_to_monitor' do

    it 'populates @processes_to_monitor if process_regex matches any running process commands' do

    end

    it 'sets @processes_to_monitor an empty hash if process_regex does not match any running process' do

    end

    it 'sets @processes_to_monitor an empty hash if process_regex is nil' do

    end

    it 'sets @processes_to_monitor to all processes if process_regex is .*' do

    end

  end

  describe '.parse_atop_log' do

    it 'creates new PerformanceResult object with valid values' do

    end

  end

  describe 'PerformanceResult::initialize' do

    it 'properly averages arrays of values' do

    end

    it 'sets overall averages to 0 if no values are set' do

    end

    it 'raises an exception if :mem, :cpu, :disk_read or :disk_write args do not exist' do

    end

    it 'creates a result without no process data if @processes_to_monitor is empty or nil' do

    end

    it 'raises an exception if :mem, :cpu, :disk_read or :disk_write args do not exist' do

    end

  end

  describe 'PerformanceResult::log' do

    it 'prints out the results' do

    end

  end
end


