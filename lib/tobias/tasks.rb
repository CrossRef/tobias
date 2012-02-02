require "resque"
require "mongo"
require "nokogiri"
require_relative "oai/record"
require_relative "oai/list_records"
require_relative "config"

module Tobias

  Config.load!

  class DispatchDirectory
    @queue = :directories

    def self.perform(directory_name)
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
      grid = Config.grid
      Oai::ListRecords.new(File.new(filename)).each_record do |record_xml|
        Resque.enqueue(ParseRecord, grid.put(record_xml).to_s)
      end
    end
  end

  class ParseRecord
    @queue = :records

    def self.perform(id)
      oid = BSON::ObjectId.from_string id
      grid = Config.grid
      record = Oai::Record.new(Nokogiri::XML(grid.get(oid).data))
      coll = Config.collection "citations"

      docs = record.citations.map do |citation|
        {
          :from => record.doi,
          :to => citation,
          :context => {
            :header => record.header,
            :publication_date => record.publication_date
          }
        }
      end

      coll.insert(docs)
      grid.delete(oid)
    end
  end

end

