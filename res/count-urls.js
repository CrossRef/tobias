var mapF = function() {
  var value = {cite_count: 1, other_count: 0, dx_count: 0, 
               wiki_count: 0, ncbi_count: 0, ct_count: 0,
               parsed_count: 0, status_count: 0,
               ok_count: 0, not_found_count: 0}
  var url = this.url

  if (url !== undefined) {
    if (url.root !== undefined) {
      value["parsed_count"] = 1
    }

    if (url.status !== undefined) {
      value["status_count"] = 1

      if (url.status.status === "ok") {
        value["ok_count"] = 1
      } else if (url.status.status === "http_error" && url.status.code === 404) {
        value["not_found_count"] = 1
      }
    }

    if (url.tld === "org" && url.root === "doi" && url.sub === "dx") {
      value["dx_count"] = 1
    } else if (url.tld === "gov" && url.root === "nih" && url.sub === "www.ncbi.nlm") {
      value["ncbi_count"] = 1
    } else if (url.tld === "gov" && url.root === "clinicaltrials") {
      value["ct_count"] = 1
    } else if (url.root === "wikipedia") {
      value["wiki_count"] = 1
    } else {
      value["other_count"] = 1
    }
  }
  
  emit(this.context.publication_date.year, value)
}

var reduceF = function(key, vals) {
  var result = {}
  
  for (var i in vals) {
    for (var k in vals[i]) {
      if (result[k] === undefined) {
        result[k] = 0
      }
      result[k] += vals[i][k]
    }
  }

  return result
}

db.runCommand({
  mapreduce: "citations",
  map: mapF,
  reduce: reduceF,
  query: {"to.unstructured_citation": {"$exists": true}},
  out: {replace: "url_counts"},
  verbose: true
})
