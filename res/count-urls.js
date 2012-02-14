var mapF = function() {
  var value = {cite_count: 1, other_count: 0, dx_count: 0, wiki_count: 0, ncbi_count: 0, ct_count: 0}
  var url = this.url

  if (url !== undefined) {
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
  var citeSum = 0, otherSum = 0, dxSum = 0, wikiSum = 0, ncbiSum = 0, ctSum = 0

  for (var i in vals) {
    citeSum += vals[i]["cite_count"]
    otherSum += vals[i]["other_count"]
    dxSum += vals[i]["dx_count"]
    wikiSum += vals[i]["wiki_count"]
    ncbiSum += vals[i]["ncbi_count"]
    ctSum += vals[i]["ct_count"]
  }
  
  return {cite_count: citeSum, 
          other_count: otherSum, 
          dx_count: dxSum,
          wiki_count: wikiSum,
          ncbi_count: ncbiSum,
          ct_count: ctSum}
}

db.runCommand({
  mapreduce: "citations",
  map: mapF,
  reduce: reduceF,
  query: {"to.unstructured_citation": {"$exists": true}},
  out: {replace: "url_counts"},
  verbose: true
})
