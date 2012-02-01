require "resque"
require "mongo"
require "nokogiri"
require_relative "oai/record"
require_relative "oai/list_records"
require_relative "config"

module Tobias

  class DispatchDirectory
    @queue = :directories

    def self.perform(directory_name)
      @citations.ensure_index "from.doi"
      @citations.ensure_index "to.doi"
      
      Dir.new(directory_name).each do |filename|
        if filename.end_with? ".xml"
          Resque.enqueue(SplitRecordList, File.join(directory_name, filename))
        end
      end
    end
  end

  class SplitRecordList
    @queue = :files

    def self.perform(filename)
      ListRecords.new(File.new(filename)).each_record do |record_xml|
        Resque.enqueue(ParseRecord, record_xml)
      end
    end
  end

  class ParseRecord
    @queue = :records

    def self.perform(xml)
      record = Record.new(Nokogiri::XML(xml))
      coll = Config.mongo["citations"]

      record.citations.each do |citation|
        cite_doc = {
          :from => record.doi,
          :to => citation,
          :context => {
            :header => record.header,
            :publication_date => record.publication_date
          }
        }
        coll.insert cite_doc
      end
    end
  end

end

