require "rspec"
require_relative "../lib/tobias/oai/list_records"

describe Tobias::Oai::ListRecords do

  before do
    @filename = File.join(File.dirname(__FILE__), "..", "data", "list_records.xml")
  end

  it "should iterate through all record elements" do
    records = []
    Tobias::Oai::ListRecords.new(File.new(@filename)).each_record do |record|
      record.should match /<\/record>/
      records << record
    end
    records.should have(9).things
    
  end

  it "should successfully parse extracted record elements" do
    Tobias::Oai::ListRecords.new(File.new(@filename)).each_record do |xml|
      record = Tobias::Oai::Record.new(Nokogiri::XML(xml))
      record.citing_doi.should have(2).things
      record.header.should have(3).things
    end
  end

end
