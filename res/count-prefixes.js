var dataCitePrefixes = [
  "10.1594",
  "10.2311",
  "10.2312",
  "10.2314",
  "10.3203",
  "10.3204",
  "10.3205",
  "10.3206",
  "10.3207",
  "10.3285",
  "10.3334",
  "10.4118",
  "10.4121",
  "10.4122",
  "10.4123",
  "10.4125",
  "10.4126",
  "10.4224",
  "10.4225",
  "10.4228",
  "10.4229",
  "10.4230",
  "10.4231",
  "10.4232",
  "10.4233",
  "10.5060",
  "10.5061",
  "10.5062",
  "10.5063",
  "10.5064",
  "10.5065",
  "10.5066",
  "10.5067",
  "10.5068",
  "10.5069",
  "10.5071",
  "10.5073",
  "10.5156",
  "10.5157",
  "10.5160",
  "10.5161",
  "10.5162",
  "10.5165",
  "10.5255",
  "10.5257",
  "10.5259",
  "10.5282",
  "10.5283",
  "10.5284",
  "10.5285",
  "10.5286",
  "10.5287",
  "10.5288",
  "10.5290",
  "10.5291",
  "10.5438",
  "10.5439",
  "10.5441",
  "10.5442",
  "10.5444",
  "10.5445",
  "10.5447",
  "10.5520",
  "10.5524",
  "10.5675",
  "10.5676",
  "10.5677",
  "10.5678",
  "10.5681",
  "10.5682",
  "10.5684",
  "10.5880",
  "10.5881",
  "10.5882",
  "10.6091"
]

var mapF = function() {
  var citation = this.to.unstructured_citation
  var doi = this.to.doi

  for (var i in prefixes) {
    if (citation && citation.match(prefixes[i])) {
      emit(prefixes[i], {unstructured: 1, structured: 0})
    }

    var re = new RegExp("^" + prefixes[i])

    if (doi && doi.match(re)) {
      emit(prefixes[i], {unstructured: 0, structured: 1})
    }
  }
}

var reduceF = function(key, vals) {
  var structuredSum = 0
  var unstructuredSum = 0

  for (var i in vals) {
    structuredSum += vals[i]["structured"]
    unstructuredSum += vals[i]["unstructured"]
  }

  return {structured: structuredSum, unstructured: unstructuredSum}
}

db.runCommand({
  mapreduce: "citations",
  map: mapF,
  reduce: reduceF,
  query: {"$or": [{"to.unstructured_citation": {"$exists": true}}, {"to.doi": {"$exists": true}}]},
  out: {replace: "prefix_counts"},
  verbose: true,
  scope: {prefixes: dataCitePrefixes}
})
