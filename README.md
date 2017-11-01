# beaker-benchmark

A tool for monitoring performance on a puppet infrastructure node while performing some actions.

# Usage
        # Monitor performance on the master while pe-puppetserver is starting up
        test_name('measure_perf_on_puppetserver_start') {
          on(master, 'puppet resource service pe-puppetserver ensure=stopped', true)
          measure_perf_on('start_pe-puppetserver', master) {
            on(master, 'puppet resource service pe-puppetserver ensure=running')
          }
        }

        # Example output:
        Action: measure_perf_on_puppetserver_start_start_pe-puppetserver, Duration: 37.463595
        Avg CPU: 172%, Avg MEM: 1634829, Avg DSK read: 0, Avg DSK Write: 45
        Additional output if include_processes:
          Process pid: 14067, command: '/opt/puppetlabs/server/apps/postgresql/bin/postgres -D /opt/puppetlabs/server/data/postgresql/9.6/data -c log_directory=/var/log/puppetlabs/postgresql'
              Avg CPU: '0', Avg MEM: 48888, Avg DSK read: 0, Avg DSK Write: 48888
