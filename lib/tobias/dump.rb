# -*- coding: utf-8 -*-
require_relative 'oai/list_records'
require_relative 'oai/record'
require_relative 'tasks'
require_relative 'config'

require 'csv'
require 'nokogiri'

module Tobias

  class DumpCitations < ConfigTask
    def self.parse_directory csv, directory_path
      Dir.entries(directory_path).each do |filename|
        if filename != '.' && filename != '..'
          path = File.join(directory_path, filename)
          
          if File.directory?(path)
            parse_directory(csv, path)
          elsif filename.end_with?('.xml')
            puts "Running for #{path}"
            parse_records(csv, path)
          end
        end
      end
    end
    
    def self.parse_records csv, file_path
      Oai::ListRecords.new(File.new(file_path)).each_record do |record_xml|
        dump_record(csv, record_xml)
      end
    end

    def self.dump_record csv, record_xml
      issns_coll = Config.collection('issns')
      record = Oai::Record.new(Nokogiri::XML(record_xml))
      dump_data = {}

      # If there is no citing DOI don't bother to parse record.
      if record.citing_doi[:doi].nil?
        return
      end

      # Determine if the DOI is an article and if its journal has categories
      if record.citing_kind == 'journal_article'
        journal = record.citing_journal

        unless journal.nil? || journal[:issn].nil?
          issn = Helpers.normalise_issn(journal[:issn])
          issn_r = issns_coll.find_one({'$or' => [{:e_issn => issn}, {:p_issn => issn}]})
          
          if issn_r.nil? || issn_r['categories'].nil?
            dump_data[:categories] = ''
          else
            dump_data[:categories] = issn_r['categories'].join(';')
          end
        end
      end

      # Get the DOI of the record
      dump_data[:doi] = record.citing_doi[:doi]

      # Get its type
      dump_data[:type] = record.citing_kind

      # Dump each citation along with the data above
      record.citations.each do |citation|
        if !citation[:doi].nil? || !citation[:unstructured_citation].nil?
          line = [dump_data[:doi], 
                  dump_data[:type], 
                  dump_data[:categories], 
                  citation[:unstructured_citation],
                  citation[:doi]]

          unless line[3] == '' && line[4] == ''
            csv << line
          end
        end
      end
    end

    def self.perform directory_path
      CSV.open('citations.csv', 'wb', {:force_quotes => true}) do |csv|
        puts "Start dir is #{directory_path}"
        parse_directory(csv, directory_path)
      end
    end
  end

end
