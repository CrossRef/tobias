# -*- coding: utf-8 -*-
require 'fileutils'
require 'date'

require_relative 'tasks'
require_relative 'config'

module Tobias

  DAYS_PER_HARVEST = 2

  # Find all changed records and injest them into mongo.
  class GetChangedRecords < ConfigTask
    @queue = :harvest

    def self.run_query query, data_path, action
      resumption_count = 0
      response = Config.oai_client.list_records(query)
      File.open(File.join(data_path, "#{resumption_count}.xml"), 'w') do |file|
        file << response.doc
      end
        
      while !response.resumption_token.nil? && !response.resumption_token.empty?
        puts "Resuming with #{response.resumption_token}"
        resumption_count = resumption_count.next
        10.times do
          begin
            response = Config.oai_client.list_records(:resumption_token => response.resumption_token)
            file_path = File.join(data_path, "#{resumption_count}.xml")
            File.open(file_path, 'w') do |file|
              file << response.doc
            end
            Resque.enqueue(SplitRecordList, file_path, action)
            record_file_dispatch(file_path, action)
            break
          rescue Exception => e
            puts "Retrying due to #{e}"
            sleep 3
          end
        end
      end
    end

    def self.perform from_date, until_date, action
      from_date = Date.strptime(from_date, '%Y-%m-%d')
      until_date = Date.strptime(until_date, '%Y-%m-%d')

      query = {
        :from => from_date,
        :until => until_date,
        :metadata_prefix => 'cr_unixml'
      }

      ['J', 'B', 'S'].each do |set|
        leaf_dir = "#{set}-#{from_date.strftime('%Y-%m-%d')}-to-#{until_date.strftime('%Y-%m-%d')}"
        data_path = File.join(Config.data_home, 'oai', leaf_dir)
        FileUtils.mkpath(data_path)
        query = query.merge({:set => set})
        run_query(query, data_path, action)
      end
    end
  end
 
  # Harvests many two-day date ranges within a given date range
  class HarvestDateRange
    @queue = :harvest

    def self.queue_up from_date, until_date, action
      Resque.enqueue(GetChangedRecords, from_date, until_date, action)
      puts "Enqueue harvest for #{from_date.to_s} to #{until_date.to_s}"
    end

    def self.perform from_date, until_date, action
      from_date = Date.strptime(from_date, '%Y-%m-%d')
      until_date = Date.strptime(until_date, '%Y-%m-%d')
     
      days = until_date - from_date

      (days / DAYS_PER_HARVEST).to_i.times do
        queue_up(from_date, from_date + (DAYS_PER_HARVEST - 1), action)
        from_date = from_date + DAYS_PER_HARVEST
      end

      if from_date != until_date
        queue_up(from_date, until_date, action)
      end
    end
  end

end

