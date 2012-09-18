# -*- coding: utf-8 -*-
require 'fileutils'

require_relative 'tasks'
require_relative 'config'

module Tobias

  DAYS_PER_HARVEST = 2

  # Find all changed records and injest them into mongo.
  class GetChangedRecords < ConfigTask
    @queue = :harvest

    def self.perform since_date, until_date, action
      since_date = Date.strptime(since_date, '%Y-%m-%d')
      until_date = Date.strptime(until_date, '%Y-%m-%d')
      leaf_dir = "#{since_date.strftime('%Y-%m-%d')}-to-#{until_date.strftime('%Y-%m-%d')}"
      data_path = File.join(Config.data_home, 'oai', leaf_dir)
      resumption_count = 0
      query = {
        :from => since_date,
        :until => until_date,
        :metadata_prefix => 'cr_unixml'
      }

      FileUtils.mkpath(data_path)

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
  end
 
  # Harvests many week-long date ranges within a given date range
  class HarvestDateRange
    @queue = :harvest

    def self.queue_up from_date, until_date, action
      f = from_date.strftime('%Y-%m-%d')
      u = until_date.strftime('%Y-%m-%d')
      Resqueue.enqueue(GetChangedRecords, f, u, action)
      puts "Enqueue harvest for #{f} to #{u}"
    end

    def self.perform from_date, until_date, action
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

