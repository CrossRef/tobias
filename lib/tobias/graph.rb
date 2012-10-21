# -*- coding: utf-8 -*-
require_relative 'oai/list_records'
require_relative 'oai/record'
require_relative 'tasks'

module Tobias
  module Graph

    # Queue up a bunch of OAI xml files for load into neo4j
    class LoadRecordFiles
      @queue = :graph

      def self.load_directory dir
        Dir.entries(dir) do |filename|
          if filename != '.' && filename != '..'
            file_path = File.join(dir, filename)

            if File.directory? file_path
              load_directory(file_path)
            elsif filename.end_with?('.xml')
              Resque.enqueue(LoadRecords, file_path)
            end
          end
        end
      end

      def self.perform dirs
        dirs.each do |dir|
          load_directory(dir)
        end
      end   
    end
    
    # Load OAI xml into neo4j
    class LoadRecords < ConfigTask
      @queue = :graph

      def self.perform file_path
        issn_coll = Config.collection 'issns'

        ListRecords.new(file_path).each_record do |xml|
          record = Record.new(xml)
          citing_doi_info = record.citing_doi

          unless citing_doi_info.nil? || record.citing_kind != 'journal_article'
            # Find category for journal ISSNs.
            # If biomedical, dump citations
            
            
          end
        end
      end
    end

  end
end
