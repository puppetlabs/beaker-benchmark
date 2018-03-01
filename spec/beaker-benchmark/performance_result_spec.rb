require 'spec_helper'

class ClassMixedWithDSLHelpers
  include BeakerTestHelpers
  include Beaker::DSL::BeakerBenchmark::Helpers

  def logger
    RSpec::Mocks::Double.new('logger').as_null_object
  end

end

describe ClassMixedWithDSLHelpers do
  subject { Beaker::DSL::BeakerBenchmark::Helpers::PerformanceResult.new (
            {:cpu => [60, 40], :mem => [6000, 4000], :disk_write => [600, 400], :action => 'test_action', :duration => 10,
             :processes => {1000 => {:cmd => 'proc1', :cpu_usage => [10, 20], :mem_usage => [1000, 2000], :disk_write => [100, 200]},
                            2000 => {:cmd => 'proc2', :cpu_usage => [20, 40], :mem_usage => [2000, 4000], :disk_write => [200, 400]}},
             :logger => logger, :hostname => 'my_host'}) }

  describe 'initialize' do

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

  describe 'log_summary' do

    it 'prints out the results' do

    end

  end

  describe 'log_csv' do

    it 'prints out the results in CSV format' do
      file_path = subject.log_csv
      file = File.open file_path
      csv_file_content = file.read
      expected_content = <<-EOS
Action,Duration,Avg CPU,Avg MEM,Avg DSK read,Avg DSK Write
test_action,10,50,5000,,500

Process pid,command,Avg CPU,Avg MEM,Avg DSK read,Avg DSK Write
1000,'proc1',15,1500,,150
2000,'proc2',30,3000,,300
      EOS
      expect(csv_file_content).to eq(expected_content)
    end

  end

end
