require "resque"
require_relative "tasks"
require_relative "config"

module Tobias

  class Runner

    def initialize dir_name
      Config.load!

      coll = Config.collection "citations"
      coll.create_index "from.doi"
      coll.create_index "to.doi"

      Resque.enqueue(DispatchDirectory, dir_name)

      Config.shutdown!
    end

  end
end
