require "nokogiri"
require_relative "record"

module Tobias
  module Oai

    class ListRecords

      def initialize file
        @reader = Nokogiri::XML::Reader file
      end

      def each_record
        @reader.each do |node|
          if node.node_type == Nokogiri::XML::Reader::TYPE_ELEMENT && node.name == "record"
            yield node.outer_xml
          end
        end
      end
      
    end

  end
end
