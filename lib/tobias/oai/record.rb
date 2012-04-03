module Tobias
  module Oai
    class Record

      @@ns = {
        "xmlns" => "http://www.crossref.org/xschema/1.0"
      }

      # These kinds can have a citation list.
      @@citing_kinds = ["journal_article", "conference_paper", "book_metadata",
                        "book_series_metadata", "book_set_metadata", "content_item", 
                        "dissertation", "report-paper_metadata", "series_metadata",
                        "standard_metadata", "standard_series_metadata", "dataset"]
      
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

      # Returns the citing DOI, if any.
      def citing_doi
	if @citing_node.nil?
	  {}
	else
          @doi ||= {
            :doi => @citing_node.at_css("doi_data doi", @@ns).text,
            :resource => @citing_node.at_css("doi_data resource", @@ns).text
          }
	end
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
	if @citing_node.nil?
	  []
	else
          @citations ||= @citing_node.css("citation", @@ns).map do |cite_node|
            citation = {:key => cite_node["key"]}
            cite_node.children.reject {|n| not n.element? }.each do |cite_item_node|
              citation[cite_item_node.name.to_sym] = cite_item_node.text
            end
            citation
          end
        end
      end

      # Will return one of:
      # - journal_article
      # - conference_paper
      # - book
      # - book_series
      # - book_set
      # - content_item
      # - dissertation
      # - report_paper
      # - series
      # - standard
      # - standard_series
      # - dataset
      def citing_kind
        normalise_work_name @citing_node.name
      end

      # Returns all DOIs in the record and the item node they belong to.
      def dois
        @dois ||= @record_node.css("doi_data", @@ns).map do |doi_node|
          {
            :doi => doi_node.at_css("doi", @@ns).text,
            :parent => doi_node.parent,
            :type => normalise_work_name(doi_node.parent.name)
          }
        end
      end

      # Return a record of bibliographic metadata for each DOI in this record.
      def bibo_records
        @bibo_records ||= dois.map do |doi_info|
          record_base = {
            :doi => doi_info[:doi],
            :type => doi_info[:type]
          }

          conj_published(record_base, doi_info[:parent])
          conj_contributors(record_base, doi_info[:parent])
          conj_title(record_base, doi_info[:parent])
          conj_pages(record_base, doi_info[:parent])

          conj_journal(record_base, doi_info[:parent].parent)
          conj_proceedings(record_base, doi_info[:parent].parent)

          record_base
        end
      end

      private

      def children_to_hash parent, ignore=[]
        ignore << :text
        hsh = {}
        parent.children.each do |child|
          key = child.name.to_sym
          if not ignore.member? key 
            hsh[key] = child.text
          end
        end
        hsh
      end

      def with_child parent_node, css
        child_node = parent_node.at_css(css, @@ns)
        if not child_node.nil?
          yield child_node
        else
          nil
        end
      end

      def normalise_work_name name
        name.sub(/_metadata\Z/, "").gsub(/-/, "_")
      end

      def conj_published record, parent_node
        with_child parent_node, "publication_date" do |pub_date_node|
          record[:published] = children_to_hash pub_date_node
        end
      end

      def conj_contributors record, parent_node
        with_child parent_node, "contributors" do |contributors_node| 
          record[:contributors] = contributors_node.css("person_name", @@ns).map do |person_node|
            children_to_hash person_node
          end
        end
      end

      def conj_title record, parent_node
        with_child(parent_node, "title") { |title_node| record[:title] = title_node.text }
      end

      def conj_volume record, parent_node
        with_child(parent_node, "volume") { |volume_node| record[:volume] = volume_node.text }
      end

      def conj_issue record, parent_node
        with_child(parent_node, "issue") { |issue_node| record[:issue] = issue_node.text }
      end

      def conj_pages record, parent_node
        with_child(parent_node, "pages") { |pages_node| record[:pages] = children_to_hash(pages_node) }
      end
      def conj_proceedings record, conference_node
        with_child conference_node, "proceedings_metadata" do |proceedings_node|
          proceedings_record = {}

          with_child proceedings_node, "proceedings_title" do |title_node|
            proceedings_record[:title] = title_node.text
          end

          with_child proceedings_node, "proceedings_subject" do |subject_node|
            proceedings_record[:subject] = subject_node.text
          end

          record[:proceedings] = proceedings_record

          conj_volume record, proceedings_node
        end
      end

      def conj_journal record, journal_node
        with_child journal_node, "journal_metadata" do |metadata_node|
          journal = children_to_hash metadata_node, [:issn]
          
          metadata_node.css("issn", @@ns).each do |issn_node|
            media_type = issn_node.attributes["media_type"]
            
            if !media_type.nil? && media_type.value == "print"
              journal[:p_issn] = issn_node.text
            elsif !media_type.nil? && media_type.value == "electronic"
              journal[:e_issn] = issn_node.text
            else
              journal[:issn] = issn_node.text
            end
          end

          if not journal.key?(:issn)
            journal[:issn] = journal[:p_issn] || journal[:e_issn]
          end

          record[:journal] = journal

          conj_volume record, journal_node
          conj_issue record, journal_node
        end
      end

    end
  end
end
