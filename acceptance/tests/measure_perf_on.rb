require 'beaker-benchmark'
require 'fileutils'

# Acceptance level testing goes into files in the tests directory like this one,
# Each file corresponding to a new test made up of individual testing steps
test_name "measure_perf_on test" do
  if Dir.exist?('tmp/atop')
    FileUtils.rm_r('tmp/atop')
  end
  result = measure_perf_on master, 'sleep test' do
    on master, 'sleep 10'
  end

  assert(File.exist?("tmp/atop/#{@@session_timestamp}/ubuntu-server-1404-x64/atop_log_measure_perf_on_test_sleep_test.log"))
  result.log_csv
  assert(File.exist?("tmp/atop/#{@@session_timestamp}/ubuntu-server-1404-x64/atop_log_measure_perf_on_test_sleep_test.csv"))
end
