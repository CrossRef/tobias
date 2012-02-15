require "resque"
require "mongo"
require "nokogiri"
require "pp"
require_relative "oai/record"
require_relative "oai/list_records"
require_relative "config"
require_relative "uri"

module Tobias

  RECORD_CHUNK_SIZE = 5000

  URL_CHUNK_SIZE = 1000
  
  URL_SAMPLE_FREQ = 0.1

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
        if (ids.count % RECORD_CHUNK_SIZE).zero?
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
              :tld => uri.tld.downcase,
              :root => uri.root.downcase,
              :sub => uri.sub.downcase
            }
          rescue StandardError => e
            doc["url"] = {:full => url}
          end
          coll.save doc
        end
      end
    end
  end

  class EmitUrls < ConfigTask
    def self.perform
      sample_size = URL_CHUNK_SIZE * URL_SAMPLE_FREQ
      coll = Config.collection "citations"
      query = {"url.root" => {"$exists" => true}} # only parsable urls
      ids = []
      
      coll.find(query, {:fields => ["_id"]}).each do |doc|
        ids << doc["_id"].to_s
        
        if (ids.count % URL_CHUNK_SIZE).zero?
          Resque.enqueue(CheckUrls, ids.sample(sample_size))
          ids = []
        end
      end
      
      Resque.enqueue(CheckUrls, ids.sample(ids.count * URL_SAMPLE_FREQ)) if not ids.empty?
    end
  end

  class CheckUrls < ConfigTask
    @queue = :urls
    
    def self.perform(ids)
      coll = Config.collection "citations"

      ids.each do |id|
        doc = coll.find_one(BSON::ObjectId.from_string(id))
        doc["url"]["status"] = URI(doc["url"]["full"]).status
        coll.save doc
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

