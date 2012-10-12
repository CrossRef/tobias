require "resque"
require_relative "tasks"
require_relative "config"

module Tobias

  class Runner

    def initialize dir_name, action
      Config.load!

      citation_coll = Config.collection "citations"
      citation_coll.create_index "from.doi"
      citation_coll.create_index "to.doi"

      doi_coll = Config.collection "dois"
      doi_coll.create_index "doi"

      Config.shutdown!

      Resque.enqueue(DispatchDirectory, dir_name, action)
    end

  end
end
