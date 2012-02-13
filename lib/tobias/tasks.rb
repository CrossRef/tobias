require "resque"
require "mongo"
require "nokogiri"
require "pp"
require_relative "oai/record"
require_relative "oai/list_records"
require_relative "config"
require_relative "uri"

module Tobias

  class ConfigTask
    def self.before_perform_config(*args)
      Config.load!
    end

    def self.after_perform_config(*args)
      Config.shutdown!
    end
  end

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

  class SplitRecordList < ConfigTask
    @queue = :files

    def self.perform(filename)
      grid = Config.grid
      ids = []
      
      Oai::ListRecords.new(File.new(filename)).each_record do |record_xml|
        ids << grid.put(record_xml).to_s
        if (ids.count % 5000).zero?
          Resque.enqueue(ParseRecords, ids)
          ids = []
        end
      end

      Resque.enqueue(ParseRecords, ids) unless ids.empty?
    end
  end

  class ParseRecords < ConfigTask
    @queue = :records

    def self.perform(ids)
      grid = Config.grid
      coll = Config.collection "citations"
      docs = []

      ids.each do |id|
        oid = BSON::ObjectId.from_string id
        record = Oai::Record.new(Nokogiri::XML(grid.get(oid).data))
        
        docs = record.citations.map do |citation|
          {
            :from => record.citing_doi,
            :to => citation,
            :context => {
              :header => record.header,
              :publication_date => record.publication_date,
              :kind => record.citing_kind
            }
          }
        end

        coll.insert(docs)
        grid.delete(oid)
      end
    end
  end

  class ParseUrls < ConfigTask
    def self.perform
      coll = Config.collection "citations"
      query = {"to.unstructured_citation" => {"$exists" => true}}
      checked = 0
      coll.find(query).each do |doc|
        checked = checked.next
        puts "Checked #{checked} u citations" if (checked % 100000).zero?
        citation = doc["to"]["unstructured_citation"]
        match = citation.match(/https?:\/\/[^\s]+/)
        if not match.nil?
          url = match[0]
          url = url.chomp(").").chomp(">.").chomp("].").chomp("}.")
          url = url.chomp("),").chomp(">,").chomp("],").chomp("},")
          url = url.chomp(")").chomp(",").chomp(".").chomp(">").chomp("]")
          url = url.chomp("}")
          begin
            uri = URI(url)
            doc["url"] = {
              :full => url,
              :tld => uri.tld,
              :root => uri.root,
              :sub => uri.sub
            }
          rescue StandardError => e
            doc["url"] = {:full => url}
          end
          coll.save doc
        end
      end
    end
  end

  def self.run_once task
    task.public_methods.reject {|n| !n.to_s.start_with? "before"}.each do |name|
      task.public_method(name).call
    end

    task.public_method(:perform).call

    task.public_methods.reject {|n| !n.to_s.start_with? "after"}.each do |name|
      task.public_method(name).call
    end
  end

end

