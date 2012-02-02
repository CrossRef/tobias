Gem::Specification.new do |s|
  s.name = "tobias"
  s.version = "0.0.1"
  s.summary = "CrossRef OAI-PMH result data parser work flow queue thing"
  s.files = Dir.glob("{lib,data,spec}/**/**/*")
  s.authors = ["Karl Jonathan Ward"]
  s.email = ["kward@crossref.org"]
  s.homepage = "http://github.com/CrossRef/tobias"
  s.required_ruby_version = ">=1.9.1"

  s.add_dependency "resque"
  s.add_dependency "mongo"
  s.add_dependency "nokogiri"
  s.add_dependency "rspec"
end

