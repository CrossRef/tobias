# -*- coding: utf-8 -*-
require "rspec"
require "nokogiri"
require_relative "../lib/tobias/oai/record"

describe Tobias::Oai::Record do

  before do
    @filename = File.join(File.dirname(__FILE__), "..", "data", "record.xml")
    @xml = File.open(@filename, "rb") { |f| f.read }
    @record = Tobias::Oai::Record.new Nokogiri::XML(@xml)
  end

  it "should report header information correctly" do
    @record.header.should == {
      :identifier => "info:doi/10.1504/IJIR.2008.019205",
      :date_stamp => "1970-01-14",
      :set_specs => ["J", "J:1504", "J:1504:76299"]
    }
  end

  it "should report publication date correctly" do
    @record.publication_date[:year].should == 2008
  end

  it "should report record doi data correctly" do
    @record.citing_doi.should == {
      :doi =>"10.1504/IJIR.2008.019205",
      :resource => "http://www.inderscience.com/link.php?id=19205"
    }
  end

  it "should report citations correctly" do
    @record.citations.count.should == 4
  end

  it "should report kind correctly" do
    @record.citing_kind.should == "journal_article"
  end

  it "should report dois and their type correctly" do
    @record.dois.count.should == 1
    @record.dois.first[:type].should == "journal_article"
    @record.dois.first[:doi].should == "10.1504/IJIR.2008.019205"
  end

  it "should report titles in bibliographic records" do
    @record.bibo_records.count.should == 1
    @record.bibo_records.first[:published][:year].should == "2008"
    @record.bibo_records.first[:contributors].count.should == 3
  end

  it "should report correct journal details" do
    journal = @record.bibo_records.first[:journal]
    journal[:full_title].should == "International Journal of Inventory Research"
    journal[:abbrev_title].should == "IJIR"
    journal[:p_issn].should == "1746-6962"
    journal[:e_issn].should == "1746-6970"
  end

end
