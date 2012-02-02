require "json"
require "mongo"

module Tobias

  module Config
    extend self

    @filename = File.join(File.dirname(__FILE__), "..", "..", "config.json")
    @location = ENV["CONFIG"] || "local"
    
    def load!(filename = @filename, location = @location)
      File.open filename, "rb" do |file|
        @config = JSON.parse(file.read)[location]
      end
    end

    def mongo
      @mongo ||= Mongo::Connection.new(@config["mongo-server"])
    end
    
    def collection collection_name
      mongo[@config["mongo-name"]][collection_name]
    end

    def grid
      @grid ||= Mongo::Grid.new(mongo[@config["mongo-name"]])
    end

    def shutdown!
      if not @mongo.nil?
        @mongo.close
        @mongo = nil
      end
    end

  end

end
