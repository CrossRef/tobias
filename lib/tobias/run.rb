require "resque"
require_relative "tasks"

Config.load!

coll = Config.collection "citations"
coll.ensure_index "from.doi"
coll.ensure_index "to.doi"

Resque.enqueue(DispatchDirectory, "/data/crossref-citations")
