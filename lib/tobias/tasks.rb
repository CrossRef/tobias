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

    def self.perform(directory_name, action)
      Dir.new(directory_name).each do |filename|
        if filename.end_with? ".xml"
          Resque.enqueue(SplitRecordList, File.join(directory_name, filename), action)
        end
      end
    end
  end

  class SplitRecordList < ConfigTask
    @queue = :files

    def self.perform(filename, action)
      grid = Config.grid
      ids = []
      
      Oai::ListRecords.new(File.new(filename)).each_record do |record_xml|
        ids << grid.put(record_xml).to_s
        if (ids.count % RECORD_CHUNK_SIZE).zero?
          Resque.enqueue(ParseRecords, ids, action)
          ids = []
        end
      end

      Resque.enqueue(ParseRecords, ids, action) unless ids.empty?
    end
  end

  class ParseRecords < ConfigTask
    @queue = :records

    def self.perform(ids, action)
      grid = Config.grid
      coll = Config.collection action.to_s
      docs = []

      ids.each do |id|
        oid = BSON::ObjectId.from_string id
        record = Oai::Record.new(Nokogiri::XML(grid.get(oid).data))
        
        if action == "citations"
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
        elsif action == "dois"
          record.bibo_records.each do |bibo_record|
            coll.update({"doi" => bibo_record[:doi]}, bibo_record, {:upsert => true})
          end
        end

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

  class UpdateSolr < ConfigTask
    def self.initials given_name
      given_name.split(/[\s\-]+/).map { |name| name[0] }.join(" ")
    end

    def self.to_solr_content doc
      index_str = ""

      if doc["published"]
        index_str << doc["published"]["year"] if doc["published"]["year"]
      end

      index_str << " " + doc["title"] if doc["title"]

      if doc["journal"]
        index_str << " " + doc["journal"]["full_title"] if doc["journal"]["full_title"]
        index_str << " " + doc["jorunal"]["abbrev_title"] if doc["journal"]["abbrev_title"]
      end

      if doc["proceedings"]
        index_str << " " + doc["proceedings"]["title"] if doc["proceedings"]["title"]
      end
      
      index_str << " " + doc["issue"] if doc["issue"]
      index_str << " " + doc["volume"] if doc["volume"]

      if doc["pages"]
        index_str << " " + doc["pages"]["first"] if doc["pages"]["first"]
        index_str << " " + doc["pages"]["last"] if doc["pages"]["last"]
      end

      if doc["contributors"]
        doc["contributors"].each do |c|
          index_str << " " + initials(c["given_name"]) if c["given_name"]
          index_str << " " + c["surname"] if c["surname"]
        end
      end

      index_str
    end

    def self.perform
      
      coll = Config.collection "dois"
      solr_docs = []

      coll.find().each do |doc|
        if ["journal_article", "conference_paper"].include? doc["type"]
          solr_docs << {
            :doi => doc["doi"],
            :content => to_solr_content(doc)
          }

          if solr_docs.count % 1000 == 0
            Config.solr.add solr_docs
            solr_docs = []
          end
        end
      end

    end
  end

end

