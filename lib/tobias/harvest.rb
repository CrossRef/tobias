# -*- coding: utf-8 -*-
require 'fileutils'

require_relative 'tasks'
require_relative 'config'

module Tobias

  # Find all changed records and injest them into mongo.
  class GetChangedRecords < ConfigTask
    @queue = :harvest

    def self.perform since_date, action
      data_path = File.join(Config.data_home, 'oai', since_date.strftime('%Y-%m-%d'))
      resumption_count = 0
      query = {
        :from => since_date,
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

end

