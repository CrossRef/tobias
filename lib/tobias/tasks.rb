# -*- coding: utf-8 -*-
require "resque"
require "mongo"
require "nokogiri"
require "json"
require_relative "oai/record"
require_relative "oai/list_records"
require_relative "config"
require_relative "uri"
require_relative 'helpers'

module Tobias

  RECORD_CHUNK_SIZE = 5000
  URL_CHUNK_SIZE = 1000
  URL_SAMPLE_FREQ = 0.1

  def self.run_once task, *args
    task.public_methods.reject {|n| !n.to_s.start_with? "before"}.each do |name|
      task.public_method(name).call
    end

    task.public_method(:perform).call(*args)

    task.public_methods.reject {|n| !n.to_s.start_with? "after"}.each do |name|
      task.public_method(name).call
    end
  end

  class ConfigTask
    def self.before_perform_config(*args)
      Config.load!
    end

    def self.after_perform_config(*args)
      Config.shutdown!
    end

    def self.record_file_dispatch file_path, action
      coll = Config.collection 'dispatches'
      doc = {
        :path => file_path,
        :created_at => Time.now,
        :action => action
      }

      coll.insert doc
    end

    def self.file_dispatched_for_action? file_path, action
      coll = Config.collection 'dispatches'
      !coll.find_one({:path => file_path, :action => action}).nil?
    end
  end

  class SetupDoiIndexes < ConfigTask
    def self.perform collection_name
      coll = Config.collection(collection_name)
      coll.ensure_index [[:random_index, 1]]
      coll.ensure_index [['published.year', 1], [:random_index, 1]]
      coll.ensure_index [[:type, 1], [:random_index, 1]]
      coll.ensure_index [[:type, 1], ['published.year', 1], [:random_index, 1]]
      coll.ensure_index [[:type, 1], ['journal.p_issn', 1], ['published.year', 1], [:random_index, 1]]
      coll.ensure_index [[:type, 1], ['journal.full_title', 1], ['published.year', 1], [:random_index, 1]]
      coll.ensure_index [[:type, 1], ['journal.p_issn', 1], [:random_index, 1]]
      coll.ensure_index [[:type, 1], ['journal.full_title', 1], [:random_index, 1]]
      coll.ensure_index [['doi', 1]]
      coll.ensure_index [['created_at', 1]]
    end
  end

  class DispatchDirectory
    @queue = :load

    def self.perform(directory_name, action)
      Dir.new(directory_name).each do |filename|
        if filename.end_with? ".xml"
          Resque.enqueue(ParseRecordList, File.join(directory_name, filename), action)
        end
      end
    end
  end

  class ParseRecordList < ConfigTask
    @queue = :load

    def self.perform(filename, action)
      grid = Config.grid
      ids = []
      action_task = action.split('_').first
      coll = Config.collection(action.to_s)

      Oai::ListRecords.new(File.new(filename)).each_record do |record_xml|
        record = Oai::Record.new(record_xml)

        case action_task
        when "citations"
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
        when "dois"
          record.bibo_records.each do |bibo_record|
            bibo_record[:updated_at] = Time.now
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


  class LoadCategories < ConfigTask
    @queue = :load

    def self.perform filename
      coll = Config.collection 'issns'

      File.open filename do |file|
        file.lines.drop(1).each do |line|
          p_issn, e_issn, category_str = line.split "\t"
          categories = category_str.split(';').map { |s| s.strip }.reject { |s| s.empty? }

          doc = {
            :p_issn => Helpers.normalise_issn(p_issn),
            :e_issn => Helpers.normalise_issn(e_issn),
            :categories => categories
          }

          doc.reject! { |_,v| v.nil? || v.empty? }

          coll.insert doc
        end
      end
    end

  end

  class LoadCategoryNames < ConfigTask
    @queue = :load

    def self.perform filename
      coll = Config.collection 'categories'

      File.open filename do |file|
        file.lines.drop(1).each do |line|
          code, name = line.split "\t"

          doc = {
            :code => code,
            :name => name.strip
          }

          coll.insert doc
        end
      end
    end

  end

  class AddNormalisedDois < ConfigTask

    def self.perform
      dois_coll = Config.collection "dois"
      completed_count = 0

      dois_coll.find({:normal_doi => {'$exists' => false}}).each do |doc|
        doc['normal_doi'] = doc['doi'].downcase
        query = {:doi => doc['doi']}
        update = {'$set' => {:normal_doi => doc['doi'].downcase}}
        dois_coll.update query, update

        completed_count = completed_count.next

        if (completed_count % 10000).zero?
          puts "Completed #{completed_count}"
        end
      end
    end

  end

  class ResolveCitations < ConfigTask

    def self.match? response
      docs = response["response"]["docs"]

      if docs.count < 2
        true
      else
        threshold = docs.map { |d| d["score"] }.drop(1).take(2).reduce(0) {|memo, val| memo += val} * 0.8
        docs.first["score"] >= threshold

        # docs.first["score"] > 1 && docs.first["score"] >= (docs[1]["score"] * 1.5)
      end
    end

    def self.correct? response, citation
      docs = response["response"]["docs"]

      if docs.empty?
        false
      else
        response["response"]["docs"].first["doi"] == citation["to"]["doi"]
      end
    end

    def self.perform
      coll = Config.collection "citations"
      results = {:good_match => 0, :bad_match => 0, :no_match => 0}
      query = {
        "$and" => [{
            "to.doi" => {"$exists" => true}
          },
          {
            "to.unstructured_citation" => {"$exists" => true}
          }
        ]}

      coll.find(query).each do |citation|
        # If the citation has an unstructured_citation we construct a query
        # using it. Otherwise, we query using a concatenation of all structured
        # query parts, unless there are none, in which case we ignore the citation.
        query = ""

        if citation["to"].key?("unstructured_citation")
          query << citation["to"]["unstructured_citation"]
        # else
        #   citation_parts = citation["to"].reject do |name, _|
        #     ["doi", "key", "issn", "isbn"].include?(name)
        #   end

        #   query = citation_parts.values.reduce("") { |memo, val| memo << " " + val }
        # end

        # if not query.empty?
          # Remove characters that are meaningful in solr query strings.
          query = query.gsub(/[():]/, " ")

          response = Config.solr.get "select", :params => {
            :q => query,
            :fl => "*,score",
            :rows => 10
          }

          if not match?(response)
            results[:no_match] = results[:no_match].next
            puts "no match: " + query
          elsif correct?(response, citation)
            results[:good_match] = results[:good_match].next
            puts "good match: " + query
          else
            results[:bad_match] = results[:bad_match].next
            puts "bad match: " + query
          end
        end
      end

      jj results
    end

  end

end

