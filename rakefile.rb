require "rspec/core/rake_task"
require "resque/tasks"
require_relative "lib/tobias/runner"

desc "Run RSpec over tests in /spec"
RSpec::Core::RakeTask.new

desc "Queue a directory of XML files for parsing"
task :queue_dir do
  require_relative "lib/runner"
  Tobias::Runner.new(ENV["DIR"] || "/data/crossref-citations")
end


