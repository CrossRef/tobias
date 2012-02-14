var mapHostsF = function() {
  if (this.url.root !== undefined) {
    emit(this.url.root, 1)
  }
}

var reduceHostsF = function(key, vals) {
  var sum = 0
  for (var i in vals) {
    sum += vals[i]
  }
  return sum
}

db.runCommand({
  mapreduce: "citations",
  map: mapHostsF,
  reduce: reduceHostsF,
  query: {"url": {"$exists": true}},
  out: {replace: "host_counts"},
  verbose: true
})
