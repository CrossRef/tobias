require "json"
require "mongo"
require "resque"
require 'rsolr'

module Tobias

  module Config

    @@filename = File.join(File.dirname(__FILE__), "..", "..", "config.json")
    @@location = ENV["CONFIG"] || "local"

    def self.load!(filename = @@filename, location = @@location)
      File.open filename, "rb" do |file|
        @@config = JSON.parse(file.read)[location]
      end
    end

    def self.redis!
      Resque.redis = @@config["redis-server"]
    end

    def self.mongo
      @@mongo ||= Mongo::Connection.new(@@config["mongo-server"])
    end

    def self.collection collection_name
      mongo[@@config["mongo-name"]][collection_name]
    end

    def self.grid
      @@grid ||= Mongo::Grid.new(mongo[@@config["mongo-name"]])
    end

    def self.solr
      @@solr ||= RSolr.connect({:url => @@config['solr-server']})
    end

    def self.shutdown!
      if not @@mongo.nil?
        @@mongo.close
        @@mongo = nil
      end
    end

  end

end
