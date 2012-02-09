var mapF = function() {
  value = {cite_count: 1, url_count: 0, dx_url_count: 0}
  citation = this.to.unstructured_citation

  if (citation.search(/http://dx\.doi\.org/)) {
    value["dx_url_count"] = 1
  } else if (citation.search(/https?://[^\s]+/)) {
    value["url_count"] = 1
  }
  
  emit(this.publication_date, value)
}

var reduceF = function(key, vals) {
  var cite_sum = 0, url_sum = 0, dx_url_sum = 0
  for (var i in vals) {
    cite_sum += vals["cite_count"]
    url_sum += vals["url_count"]
    dx_url_sum += vals["dx_url_count"]
  }
  
  return {cite_count: cite_sum, url_count: url_sum, dx_url_count: dx_url_sum}
}

db.runCommand({
  mapreduce: "citations",
  map: mapF,
  reduce: reduceF,
  query: {"to.unstructured_citation": {"$exists": true}},
  out: {replace: "url_counts"}
})
