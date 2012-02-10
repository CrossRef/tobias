var mapF = function() {
  var value = {cite_count: 1, url_count: 0, dx_url_count: 0}
  var citation = this.to.unstructured_citation

  if (citation.search(/http:\/\/dx\.doi\.org/)) {
    value["dx_url_count"] = 1
  } else if (citation.search(/https?:\/\/[^\s]+/)) {
    value["url_count"] = 1
  }
  
  emit(this.context.publication_date, value)
}

var reduceF = function(key, vals) {
  var citeSum = 0, urlSum = 0, dxUrlSum = 0
  for (var i in vals) {
    citeSum += vals[i]["cite_count"]
    urlSum += vals[i]["url_count"]
    dxUrlSum += vals[i]["dx_url_count"]
  }
  
  return {cite_count: citeSum, url_count: urlSum, dx_url_count: dxUrlSum}
}

db.runCommand({
  mapreduce: "citations",
  map: mapF,
  reduce: reduceF,
  query: {"to.unstructured_citation": {"$exists": true}},
  out: {replace: "url_counts"},
  verbose: true
})
