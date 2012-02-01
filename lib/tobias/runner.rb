require "resque"
require_relative "tasks"
require_relative "config"

module Tobias

  class Runner

    def initialize
      Config.load!

      coll = Config.collection "citations"
      coll.create_index "from.doi"
      coll.create_index "to.doi"

      Resque.enqueue(DispatchDirectory, "/data/crossref-citations")
    end

  end
end

Tobias::Runner.new