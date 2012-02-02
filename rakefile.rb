# Create an rspec test runner task.
require "rspec/core/rake_task"

desc "Run RSpec over tests in /spec"
RSpec::Core::RakeTask.new

# Include resque:work and resque:worker tasks.
require "resque/tasks"

task "resque:setup" do
  require_relative "lib/tobias/tasks"
end

# Create a directory loading task.
desc "Queue a directory of XML files for parsing"
task :queue_dir do
  require_relative "lib/tobias/runner"
  Tobias::Runner.new(ENV["DIR"] || "/data/crossref-citations")
end
