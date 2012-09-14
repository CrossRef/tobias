# -*- coding: utf-8 -*-
require 'fileutils'

require_relative 'tasks'
require_relative 'config'

module Tobias

  # Find all changed records and injest them into mongo.
  class GetChangedRecords < ConfigTask
    @queue = :harvest

    def self.perform since_date
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
        response = Config.oai_client.list_records(:resumption_token => response.resumption_token)
        File.open(File.join(data_path, "#{resumption_count}.xml"), 'w') do |file|
          file << response.doc
        end
      end

    end
  end

end

