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

  describe 'setup_atop installs atop on first run' do

  end

  describe 'setup_atop sets up epel repo on el hosts on first run' do

  end

  describe 'setup_atop does not install atop after first run' do

  end

  describe 'measure_perf_on concatenates test name with action name if available' do

  end

  describe 'measure_perf_on only uses action name if test name is not available' do

  end

  describe 'start_monitoring executes atop command' do

  end

  describe 'start_monitoring executes atop command with additional arguments if include_processes=true' do

  end

  describe 'start_monitoring sets value for @beaker_benchmark_start' do

  end

  describe 'stop_monitoring sets duration, if @beaker_benchmark_start has a value' do

  end

  describe 'stop_monitoring defaults duration to 0, if @beaker_benchmark_start has no value' do

  end

  describe 'stop_monitoring kills the atop process' do

  end

  describe 'set_processes_to_monitor sets @processes_to_monitor if process_regex matches any running process commands' do

  end

  describe 'set_processes_to_monitor sets @processes_to_monitor to nil if process_regex does not match any running process' do

  end

  describe 'set_processes_to_monitor sets @processes_to_monitor to all processes if process_regex is .*' do

  end

  describe 'parse_atop_log creates new PerformanceResult object with valid values' do

  end

  describe 'PerformanceResult::initialize properly averages arrays of values' do

  end

  describe 'PerformanceResult::initialize sets overall averages to 0 if no values are set' do

  end

  describe 'PerformanceResult::initialize raises an exception if :mem, :cpu, :disk_read or :disk_write args do not exist' do

  end

  describe 'PerformanceResult::log prints out the results' do
    
  end
end


