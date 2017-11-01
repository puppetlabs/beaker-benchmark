require 'csv'

module Beaker
  module DSL
    module BeakerBenchmark
      module Helpers

        # Example usage:
        # test_name('measure_perf_on_puppetserver_start') {
        #   on(master, 'puppet resource service pe-puppetserver ensure=stopped')
        #   result = measure_perf_on(master, 'start_pe-puppetserver', true) {
        #     on(master, 'puppet resource service pe-puppetserver ensure=running')
        #     # on(master, 'facter fqdn')
        #   }
        #   raise("pe-puppetserver restart took longer than 120 seconds: #{result.duration} seconds") if result.duration > 120
        #   raise("pe-puppetserver restart used an average of more than 1gb of memory: #{result.avg_mem} bytes") if result.avg_mem > 1073741824
        #   process_cpu = result.processes.select{ |pid, process| process[:cmd] =~ /puppet-server-release.jar/ }.values[0][:avg_cpu]
        #   raise("pe-puppetserver restart caused pe-puppetserver service to use more than 95% of CPU: #{process_cpu}") if process_cpu > 95
        # }
        def measure_perf_on(infrastructure_host, action_name, include_processes=false, process_regex='/opt/puppetlabs', &block)
          # Append action name to test case name if test name is available
          action_name = metadata[:case][:name] + "_#{action_name}" if defined? metadata && metadata[:case] && metadata[:case][:name]

          atop_log = 'atop_log.log'

          start_monitoring(infrastructure_host, atop_log, include_processes)

          yield

          stop_monitoring(infrastructure_host, action_name, atop_log, include_processes.nil? ? nil : process_regex)
        end

        def setup_atop(infrastructure_host)
          @benchmark_tmpdir = Dir.mktmpdir
          # Only install atop once per host
          unless infrastructure_host.check_for_package('atop')
            add_el_extras(infrastructure_host)
            infrastructure_host.install_package('atop')
          end
        end

        def start_monitoring(infrastructure_host, atop_log, include_processes=false, sample_interval=1)
          setup_atop(infrastructure_host)
          additional_args = ''
          additional_args = ',PRC,PRM,PRD' if include_processes
          atop_cmd        = "sh -c 'nohup atop -P CPU,SWP,DSK#{additional_args} -i #{sample_interval} > #{atop_log} 2>&1 &'"

          on(infrastructure_host, atop_cmd)
          @beaker_benchmark_start = Time.now
        end

        def stop_monitoring(infrastructure_host, action_name, atop_log_name, process_regex='.*')
          if defined?@beaker_benchmark_start && !@beaker_benchmark_start.nil?
            duration = Time.now - @beaker_benchmark_start
          else
            duration = nil
          end

          # The atop process sticks around unless killed
          on infrastructure_host, 'pkill -15 -f atop'
          set_processes_to_monitor(infrastructure_host, process_regex) if process_regex
          parse_atop_log(infrastructure_host, action_name, duration, atop_log_name)
        end

        def parse_atop_log(infrastructure_host, action_name, duration, atop_log_name)
          unless infrastructure_host.file_exist?(atop_log_name)
            raise("atop log does not exist at #{atop_log_name}")
          end

          scp_from(infrastructure_host, atop_log_name, '/tmp')
          cpu_usage  = []
          mem_usage  = []
          disk_read  = []
          disk_write = []

          process_cpu = []
          skip        = true
          CSV.parse(File.read("/tmp/#{atop_log_name}"), { :col_sep => ' ' }) do |row|
            #skip the first entry, until the first separator 'SEP'.
            measure_type = row[0]
            if skip
              skip = (measure_type != 'SEP')
              next
            end
            case measure_type
              when 'CPU'
                cpu_usage.push(row[9].to_i)
              when 'SWP'
                mem_usage.push(row[10].to_i)
              when 'DSK'
                disk_read.push(row[9].to_i)
                disk_write.push(row[11].to_i)
              when 'PRC'
                add_process_measure(:cpu_usage, row[6], row[10].to_i)
              when 'PRM'
                add_process_measure(:mem_usage, row[6], row[11].to_i)
              when 'PRD'
                add_process_measure(:disk_read, row[6], row[11].to_i)
                add_process_measure(:disk_write, row[6], row[14].to_i)
            end
          end

          PerformanceResult.new({ :cpu => cpu_usage, :mem => mem_usage, :disk_read => disk_read, :disk_write => disk_write, :action => action_name, :duration => duration, :processes => @processes_to_monitor })
        end

        def set_processes_to_monitor(infrastructure_host, process_regex)
          @processes_to_monitor = {}
          result = on(infrastructure_host, "ps -eo pid,cmd | grep #{process_regex}").output
          result.each_line do |line|
            # use the PID as key and command with args as value
            # also ignore the ps and grep commands executed above.
            unless line.include? 'grep /opt/puppetlabs'
              @processes_to_monitor[line.split(' ').first] = { :cmd => line.split(' ')[1..-1].join(' '), :cpu_usage => [], :mem_usage => [], :disk_read => [], :disk_write => [] }
            end
          end
          @logger.info result.stdout
        end

        def add_process_measure measure_type, pid, value
          if @processes_to_monitor.keys.include? pid
            @processes_to_monitor[pid][measure_type].push value
          end
        end

        # Example output:
        #   Action: measure_perf_on_puppetserver_start_start_pe-puppetserver, Duration: 37.463595
        #   Avg CPU: 172%, Avg MEM: 1634829, Avg DSK read: 0, Avg DSK Write: 45
        # Additional output if include_processes:
        #   Process pid: 14067, command: '/opt/puppetlabs/server/apps/postgresql/bin/postgres -D /opt/puppetlabs/server/data/postgresql/9.6/data -c log_directory=/var/log/puppetlabs/postgresql'
        #       Avg CPU: '1', Avg MEM: 48888, Avg DSK read: 0, Avg DSK Write: 20
        class PerformanceResult
          attr_accessor :avg_cpu, :avg_mem, :avg_disk_read, :avg_disk_write, :action_name, :duration, :processes
          def initialize(args)
            @avg_cpu = args[:cpu].empty? ? 0 : args[:cpu].inject{ |sum, el| sum + el } / args[:cpu].size
            @avg_mem = args[:mem].empty? ? 0 : args[:mem].inject{ |sum, el| sum + el } / args[:mem].size
            @avg_disk_read = args[:disk_read].empty? ? 0 : args[:disk_read].inject{ |sum, el| sum + el } / args[:disk_read].size
            @avg_disk_write = args[:disk_write].empty? ? 0 : args[:disk_write].inject{ |sum, el| sum + el } / args[:disk_write].size
            @action_name = args[:action]
            @duration = args[:duration]
            @processes = args[:processes]

            @processes.keys.each do |key|
              @processes[key][:avg_cpu] = @processes[key][:cpu_usage].inject{ |sum, el| sum + el } / @processes[key][:cpu_usage].size unless @processes[key][:cpu_usage].empty?
              @processes[key][:avg_mem] = @processes[key][:mem_usage].inject{ |sum, el| sum + el } / @processes[key][:mem_usage].size unless @processes[key][:mem_usage].empty?
              @processes[key][:avg_disk_read] = @processes[key][:disk_read].inject{ |sum, el| sum + el } / @processes[key][:disk_read].size unless @processes[key][:disk_read].empty?
              @processes[key][:avg_disk_write] = @processes[key][:disk_write].inject{ |sum, el| sum + el } / @processes[key][:disk_write].size unless @processes[key][:disk_write].empty?
            end
            # TODO: At this point, we need to push these results into bigquery or elasticsearch
            # so we can normalize results over time and report on increases in trends
          end

          def log
            @logger.info "Action: #{@action_name}, Duration: #{@duration}"
            @logger.info "Avg CPU: #{@avg_cpu}%, Avg MEM: #{@avg_mem}, Avg DSK read: #{@avg_disk_read}, Avg DSK Write: #{@avg_disk_write}"
            @processes.keys.each do |key|
              @logger.info "Process pid: #{key}, command: '#{@processes[key][:cmd]}'"
              @logger.info "   Avg CPU: '#{@processes[key][:avg_cpu]}%', Avg MEM: #{@processes[key][:avg_cmem]}, Avg DSK read: #{@processes[key][:avg_disk_read]}, Avg DSK Write: #{@processes[key][:avg_disk_write]}"
            end
          end
        end

      end
    end
  end
end
