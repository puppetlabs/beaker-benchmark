require 'csv'
require 'fileutils'
require 'time'

module Beaker
  module DSL
    module BeakerBenchmark
      module Helpers
        include Beaker::HostPrebuiltSteps
        # Column indexes for atop CSV style output
        MEASURE_TYPE_INDEX = 0

        SYSTEM_CPU_INDEX = 8
        USR_CPU_INDEX = 9
        IOWAIT_CPU_INDEX = 12
        IDLE_CPU_INDEX = 11

        MEM_INDEX = 10

        DISK_READ_INDEX = 9
        DISK_WRITE_INDEX = 11

        PROC_PID_INDEX = 6

        PROC_CPU_INDEX = 16

        PROC_MEM_INDEX = 11

        PROC_DISK_READ_INDEX = 11
        PROC_DISK_WRITE_INDEX = 13

        @@session_timestamp = Time.now.getutc.to_i

        TMP_DIR = "tmp/atop/#{@@session_timestamp}"

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

          start_monitoring(infrastructure_host, action_name, include_processes)

          yield

          stop_monitoring(infrastructure_host, include_processes.nil? ? nil : process_regex)
        end

        def setup_atop(infrastructure_host)
          # Only install atop once per host
          unless infrastructure_host.check_for_package('atop')
            add_el_extras(infrastructure_host, @options)
            infrastructure_host.install_package('atop')
          end
        end

        def start_monitoring(infrastructure_host, action_name, include_processes=false, sample_interval=1)
          raise('Monitoring already in progress, call stop_monitoring before calling start_monitoring a second time') unless @beaker_benchmark_start.nil?
          @atop_log_filename = "atop_log_#{action_name.downcase.gsub(/[^a-z0-9]/i, '_')}.log"
          @action_name       = action_name
          setup_atop(infrastructure_host)
          additional_args = ''
          additional_args = ',PRC,PRM,PRD' if include_processes
          atop_cmd        = "sh -c 'nohup atop -P CPU,SWP,DSK#{additional_args} -i #{sample_interval} >  #{@atop_log_filename} 2>&1 &'"

          on(infrastructure_host, atop_cmd)
          @beaker_benchmark_start = Time.now
          return @@session_timestamp
        end

        def stop_monitoring(infrastructure_host, process_regex='.*')
          begin
            if defined?@beaker_benchmark_start && !@beaker_benchmark_start.nil?
              duration = Time.now - @beaker_benchmark_start
            else
              raise('No monitoring in progress, call start_monitoring before calling stop_monitoring')
            end

            # The atop process sticks around unless killed
            # It can also take some time to kill depending on how long it has been running and sampling rate.
            retry_on infrastructure_host, 'pkill -15 -f atop', {:max_retries => 3, :retry_interval => 5}
            set_processes_to_monitor(infrastructure_host, process_regex)
            parse_atop_log(infrastructure_host, duration)
          ensure
            @beaker_benchmark_start = nil
          end
        end

        def parse_atop_log(infrastructure_host, duration)
          unless infrastructure_host.file_exist?(@atop_log_filename)
            raise("atop log does not exist at #{@atop_log_filename}")
          end

          log_dir = "#{TMP_DIR}/#{infrastructure_host.hostname}"
          FileUtils::mkdir_p log_dir unless Dir.exist? log_dir
          scp_from(infrastructure_host, @atop_log_filename, log_dir)
          cpu_usage  = []
          mem_usage  = []
          disk_read  = []
          disk_write = []

          skip        = true
          CSV.parse(File.read(File.expand_path(@atop_log_filename, log_dir)), { :col_sep => ' ' }) do |row|
            #skip the first entry, until the first separator 'SEP'.
            measure_type = row[MEASURE_TYPE_INDEX]
            if skip
              skip = (measure_type != 'SEP')
              next
            end
            case measure_type
              when 'CPU'
                # system + usr + iowait
                cpu_active = row[SYSTEM_CPU_INDEX].to_i + row[USR_CPU_INDEX].to_i + row[IOWAIT_CPU_INDEX].to_i
                # active + idle
                cpu_total = cpu_active + row[IDLE_CPU_INDEX].to_i
                cpu_percent = cpu_active * 100 / cpu_total
                cpu_usage.push(cpu_percent)
              when 'SWP'
                mem_usage.push(row[MEM_INDEX].to_i)
              when 'DSK'
                disk_read.push(row[DISK_READ_INDEX].to_i)
                disk_write.push(row[DISK_WRITE_INDEX].to_i)
              when 'PRC'
                add_process_measure(:cpu_usage, row[PROC_PID_INDEX], row[PROC_CPU_INDEX].to_i)
              when 'PRM'
                add_process_measure(:mem_usage, row[PROC_PID_INDEX], row[PROC_MEM_INDEX].to_i)
              when 'PRD'
                # TODO: investigate why atop always shows disk_read as 0
                # add_process_measure(:disk_read, row[PROC_PID_INDEX], row[PROC_DISK_READ_INDEX].to_i)
                add_process_measure(:disk_write, row[PROC_PID_INDEX], row[PROC_DISK_WRITE_INDEX].to_i)
            end
          end

          PerformanceResult.new({ :cpu => cpu_usage, :mem => mem_usage, :disk_read => disk_read, :disk_write => disk_write, :action => @action_name, :duration => duration, :processes => @processes_to_monitor, :logger => @logger, :hostname => infrastructure_host})
        end

        def set_processes_to_monitor(infrastructure_host, process_regex)
          @processes_to_monitor = {}
          return unless process_regex
          result = on(infrastructure_host, "ps -eo pid,cmd | grep #{process_regex}").output
          result.each_line do |line|
            # use the PID as key and command with args as value
            # also ignore the ps and grep commands executed above.
            unless line.include? "grep #{process_regex}"
              @processes_to_monitor[line.split(' ').first] = { :cmd => line.split(' ')[1..-1].join(' '), :cpu_usage => [], :mem_usage => [], :disk_read => [], :disk_write => [] }
            end
          end
        end

        def add_process_measure measure_type, pid, value
          if @processes_to_monitor.keys.include? pid
            @processes_to_monitor[pid][measure_type].push value
          end
        end

        # Example output:
        #   Action: measure_perf_on_puppetserver_start_start_pe-puppetserver, Duration: 37.463595
        #   Avg CPU: 72%, Avg MEM: 1634829, Avg DSK read: 0, Avg DSK Write: 45
        # Additional output if include_processes:
        #   Process pid: 14067, command: '/opt/puppetlabs/server/apps/postgresql/bin/postgres -D /opt/puppetlabs/server/data/postgresql/9.6/data -c log_directory=/var/log/puppetlabs/postgresql'
        #       Avg CPU: '1', Avg MEM: 48888, Avg DSK Write: 20
        class PerformanceResult
          attr_accessor :avg_cpu, :avg_mem, :avg_disk_read, :avg_disk_write, :action_name, :duration, :processes, :hostname
          def initialize(args)
            @avg_cpu = args[:cpu].empty? ? 0 : args[:cpu].inject{ |sum, el| sum + el } / args[:cpu].size
            @avg_mem = args[:mem].empty? ? 0 : args[:mem].inject{ |sum, el| sum + el } / args[:mem].size
            # @avg_disk_read = args[:disk_read].empty? ? 0 : args[:disk_read].inject{ |sum, el| sum + el } / args[:disk_read].size
            @avg_disk_write = args[:disk_write].empty? ? 0 : args[:disk_write].inject{ |sum, el| sum + el } / args[:disk_write].size
            @action_name = args[:action]
            @duration = args[:duration]
            @processes = args[:processes]
            @logger = args[:logger]
            @hostname = args[:hostname] || ''


            @processes.keys.each do |key|
              @processes[key][:avg_cpu] = @processes[key][:cpu_usage].inject{ |sum, el| sum + el } / @processes[key][:cpu_usage].size unless @processes[key][:cpu_usage].empty?
              @processes[key][:avg_mem] = @processes[key][:mem_usage].inject{ |sum, el| sum + el } / @processes[key][:mem_usage].size unless @processes[key][:mem_usage].empty?
              # @processes[key][:avg_disk_read] = @processes[key][:disk_read].inject{ |sum, el| sum + el } / @processes[key][:disk_read].size unless @processes[key][:disk_read].empty?
              @processes[key][:avg_disk_write] = @processes[key][:disk_write].inject{ |sum, el| sum + el } / @processes[key][:disk_write].size unless @processes[key][:disk_write].empty?
            end if @processes
            # TODO: At this point, we need to push these results into bigquery or elasticsearch
            # so we can normalize results over time and report on increases in trends
          end

          def log_summary
            @logger.info "Action: #{@action_name}, Duration: #{@duration}"
            @logger.info "Avg CPU: #{@avg_cpu}%, Avg MEM: #{@avg_mem}, Avg DSK read: #{@avg_disk_read}, Avg DSK Write: #{@avg_disk_write}"
            @processes.keys.each do |key|
              @logger.info "Process pid: #{key}, command: '#{@processes[key][:cmd]}'"
              @logger.info "   Avg CPU: '#{@processes[key][:avg_cpu]}%', Avg MEM: #{@processes[key][:avg_mem]}, Avg DSK read: #{@processes[key][:avg_disk_read]}, Avg DSK Write: #{@processes[key][:avg_disk_write]}"
            end
          end

          def log_csv file_path=nil
            file_path = file_path || "#{TMP_DIR}/#{@hostname}/atop_log_#{action_name.downcase.gsub(/[^a-z0-9]/i, '_')}.csv"
            FileUtils.mkdir_p "#{TMP_DIR}/#{@hostname}/" unless Dir.exist?("#{TMP_DIR}/#{@hostname}/")
            file = File.open file_path, 'w'
            file.write "Action,Duration,Avg CPU,Avg MEM,Avg DSK read,Avg DSK Write\n"
            file.write "#{@action_name},#{@duration},#{@avg_cpu},#{@avg_mem},#{@avg_disk_read},#{@avg_disk_write}\n\n"
            file.write "Process pid,command,Avg CPU,Avg MEM,Avg DSK read,Avg DSK Write\n"
            @processes.keys.each do |key|
              file.write "#{key},'#{@processes[key][:cmd]}',#{@processes[key][:avg_cpu]},#{@processes[key][:avg_mem]},#{@processes[key][:avg_disk_read]},#{@processes[key][:avg_disk_write]}\n"
            end
            file.close
            file.path
          end
        end

      end
    end
  end
end
