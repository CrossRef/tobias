# -*- coding: utf-8 -*-
require "json"
require "mongo"
require "resque"
require 'rsolr'
require 'oai'

module Tobias

  module Config

    @@filename = File.join(File.dirname(__FILE__), "..", "..", "config.json")
    @@location = ENV["CONFIG"] || "local"
    @@solr_core_connections = {}

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

    # Create a solr client for a specific core
    def self.solr_core core_name
       if @@solr_core_connections.has_key?(core_name)
        @@solr_core_connections[core_name]
      else
        core_connection = RSolr.connect({:url => "#{@@config['solr-server']}/#{core_name}"})
        @@solr_core_connections[core_name] = core_connection
        core_connection
      end
    end

    def self.oai_client
      @@oai_client ||= OAI::Client.new 'http://oai.crossref.org/OAIHandler'
    end

    def self.data_home
      @@config['data-home']
    end

    def self.shutdown!
      if not @@mongo.nil?
        @@mongo.close
        @@mongo = nil
      end
    end

  end

end
