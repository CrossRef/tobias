require "json"
require "mongo"

module Tobias

  class Config

    @@filename = File.join(File.dirname(__FILE__), "..", "..", "config.json")
    @@location = ENV["LOCATION"] || "default"
    @@mongo = nil

    def self.config
      File.open @@filename, "rb" do |file|
        JSON.parse(file.read)[@@location]
      end
    end

    def self.mongo
      @@mongo ||= Mongo::Connection.new config["mongo-server"]
    end

  end

end
