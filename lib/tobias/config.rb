require "json"
require "mongo"

module Tobias

  class Config

    @@filename = File.join(File.dirname(__FILE__), "..", "..", "config.json")
    @@location = ENV["LOCATION"] or "default"
    
    def initialize(filename = @@filename, location = @@location)
      File.open filename, "rb" do |file|
        @config = JSON.parse(file.read)[location]
      end
    end

    def mongo
      @mongo ||= Mongo::Connection.new @config["mongo-server"]
    end

  end

end
