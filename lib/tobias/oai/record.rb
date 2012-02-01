module Tobias
  module Oai
    class Record

      @@ns = {
        "xmlns" => "http://www.crossref.org/xschema/1.0"
      }

      # These kinds can have a DOI and a citation list.
      @@citing_kinds = ["journal_article", "conference_paper", "book_metadata",
                        "content_item", "dissertation", "report-paper_metadata",
                        "standard_metadata", "dataset"]
      
      def initialize record_node
        @record_node = record_node
        matches = @@citing_kinds.map { |kind| @record_node.at_css(kind, @@ns) }
        @citing_node = matches.compact.first
      end

      def header
        @header ||= {
          :identifier => @record_node.at_css("header identifier").text,
          :date_stamp => @record_node.at_css("header datestamp").text,
          :set_specs => @record_node.css("header setSpec").map {|n| n.text}
        }
      end

      def doi
        @doi ||= {
          :doi => @citing_node.at_css("doi_data doi", @@ns).text,
          :resource => @citing_node.at_css("doi_data resource", @@ns).text
        }
      end

      def publication_date
        if @publication_date.nil?
          @publication_date = {}
          ["year", "month", "day"].each do |component|
            value = @citing_node.at_css("publication_date #{component}", @@ns)
            if not value.nil?
              @publication_date[component.to_sym] = value.text.strip.to_i
            end
          end
        end
        @publication_date
      end

      def citations
        @citations ||= @citing_node.css("citation", @@ns).map do |cite_node|
          citation = {:key => cite_node["key"]}
          cite_node.children.reject {|n| not n.element? }.each do |cite_item_node|
            citation[cite_item_node.name.to_sym] = cite_item_node.text
          end
          citation
        end
      end

      # Will return one of:
      # - journal_article
      # - conference_paper
      # - book
      # - content
      # - dissertation
      # - report_paper
      # - standard
      # - dataset
      def kind
        @citing_node.name.sub(/_metadata\Z/, "").gsub(/-/, "_")
      end

    end
  end
end
