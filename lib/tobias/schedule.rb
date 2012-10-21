require 'resque'

require_relative 'harvest'
require_relative 'solr'

module Tobias
  # index_on_second_core
  class ScheduledIndex
    @queue = :index
    def self.perform
      Resque.enqueue(UpdateSolr, 'labs2', 'labs1')
    end
  end

  # harvest_doi_records
  class ScheduledHarvest
    @queue = :harvest
    def self.perform
      until_date = Date.today
      from_date = until_date - 2
      Resque.enqueue(HarvestDateRange, from_date, until_date, 'dois')
    end
  end
end
