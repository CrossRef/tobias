# -*- coding: utf-8 -*-
require_relative 'tasks'
require_relative 'config'

module Tobias

  # List all changed set specs since a date. Download changed records
  # from each changed set spec via GetChangedRecords.
  class GetChangedSets < ConfigTask
    @queue = :harvest

    def self.perform(since_date)
      Config.oai_client.list_sets({:from => since_date}).each do |set_spec|
        #Resque.enqueue(GetChangedRecords, set_spec, since_date)
        puts set_spec
      end
    end
  end

  # Get records for a particular set spec and injest them into mongo via 
  # InjestRecords.
  class GetChangedRecords < ConfigTask
    @queue = :harvest

    def self.perform(set_spec, since_date)
      query = {
        :from => since_date,
        :set => set_spec
      }

      Config.oai_client.list_records(query).each do |record|
        puts record.metadata
      end
    end

  end

end

