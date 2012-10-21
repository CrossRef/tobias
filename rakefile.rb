# -*- coding: utf-8 -*-
# Create an rspec test runner task.
require "rspec/core/rake_task"

desc "Run RSpec over tests in /spec"
RSpec::Core::RakeTask.new

# Include resque:work, resque:worker and resque:scheduler tasks.
require 'resque/tasks'
require 'resque_scheduler/tasks'

namespace 'resque' do
  task 'setup' do
    require 'resque'
    require 'resque_scheduler'
    require 'resque/scheduler'

    require_relative 'lib/tobias/harvest'
    require_relative "lib/tobias/tasks"
    require_relative "lib/tobias/config"

    Tobias::Config.load!
    Tobias::Config.redis!

    case ENV['SCHEDULE']
    when 'harvest'
      Resque.schedule = YAML.load_file('config/harvest_schedule.yaml')
    when 'index'
      Resque.schedule = YAML.load_file('config/index_schedule.yaml')
    else
      puts 'Select a schedule by specifying SCHEDULE as harvest or index.'
    end
  end
end

# Create a directory loading task.
desc "Queue a directory of XML files for parsing"
task :queue_dir do
  require_relative "lib/tobias/runner"
  Tobias::Runner.new(ENV["DIR"] || "/data/crossref-citations",
                     ENV["ACTION"] || "citations")
end

task :harvest_range do
  require_relative 'lib/tobias/harvest'
  require_relative 'lib/tobias/tasks'
  from_date = Date.strptime(ENV['FROM'], '%Y-%m-%d')
  until_date = Date.strptime(ENV['UNTIL'], '%Y-%m-%d')
  action = ENV['ACTION'] || 'dois'
  Tobias.run_once Tobias::HarvestDateRange, from_date, until_date, action
end

task :harvest_recent do
  require_relative 'lib/tobias/harvest'
  require_relative 'lib/tobias/tasks'

  # Harvest range from today-2 to today, which will actually
  # harvest yesterday and the day before.
  from_date = Date.today - ENV['DAYS'].to_i
  until_date = Date.today

  action = ENV['ACTION'] || 'dois'

  Tobias.run_once Tobias::HarvestDateRange, from_date, until_date, action
end

task :parse_urls do
  require_relative "lib/tobias/tasks"
  Tobias.run_once Tobias::ParseUrls
end

task :emit_urls do
  require_relative "lib/tobias/tasks"
  Tobias.run_once Tobias::EmitUrls
end

task :index_core do
  require_relative 'lib/tobias/tasks'
  require_relative 'lib/tobias/solr'

  index_core_name = ENV['CORE'] || 'labs2'
  other_core_name = ENV['OTHER'] || 'labs1'

  Tobias.run_once Tobias::UpdateSolr, index_core_name, other_core_name
end

task :setup_doi_indexes do
  require_relative 'lib/tobias/tasks'

  Tobias.run_once Tobias::SetupDoiIndexes, ENV['COLLECTION']
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

task :compare_matches do
  require_relative 'lib/tobias/tasks'
  require_relative 'lib/tobias/resolve'

  Tobias.run_once Tobias::CompareDoiMatch, ENV['FILE']
end
