# -*- coding: utf-8 -*-
# Create an rspec test runner task.
require "rspec/core/rake_task"

desc "Run RSpec over tests in /spec"
RSpec::Core::RakeTask.new

# Include resque:work and resque:worker tasks.
require "resque/tasks"

task "resque:setup" do
  require_relative "lib/tobias/tasks"
  require_relative "lib/tobias/config"

  Tobias::Config.load!
  Tobias::Config.redis!
end

# Create a directory loading task.
desc "Queue a directory of XML files for parsing"
task :queue_dir do
  require_relative "lib/tobias/runner"
  Tobias::Runner.new(ENV["DIR"] || "/data/crossref-citations",
                     ENV["ACTION"] || "citations")
end

task :parse_urls do
  require_relative "lib/tobias/tasks"
  Tobias.run_once Tobias::ParseUrls
end

task :emit_urls do
  require_relative "lib/tobias/tasks"
  Tobias.run_once Tobias::EmitUrls
end

task :solr do
  require_relative "lib/tobias/tasks"
  Tobias.run_once Tobias::UpdateSolr
end

task :resolve do
  require_relative "lib/tobias/tasks"
  Tobias.run_once Tobias::ResolveCitations
end

task :categories do
  require_relative 'lib/tobias/tasks'
  Tobias.run_once Tobias::InjestCategories, ENV['FILE']
end

task :category_names do
  require_relative 'lib/tobias/tasks'
  Tobias.run_once Tobias::InjestCategoryNames, ENV['FILE']
end

task :add_norm_dois do
  require_relative 'lib/tobias/tasks'
  Tobias.run_once Tobias::AddNormalisedDois
end

task :scrape_doaj do
  require_relative 'lib/tobias/doaj'
  require_relative 'lib/tobias/tasks'
  Tobias.run_once Tobias::DoajScrapeTask
end

