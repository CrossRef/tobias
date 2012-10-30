# -*- coding: utf-8 -*-
require_relative 'helpers'

require 'time'

module Tobias

  class UpdateSolr < ConfigTask
    @queue = :index

    def self.clear_core core_name
      Config.solr.get 'admin/cores', :params => {
        :action => 'UNLOAD',
        :core => core_name,
        :deleteIndex => true
      }

      Config.solr.get 'admin/cores', :params => {
        :action => 'CREATE',
        :name => core_name,
        :instanceDir => core_name
      }
    end

    def self.swap_cores first_core_name, other_core_name
      Config.solr.get 'admin/cores', :params => {
        :action => 'SWAP',
        :core => first_core_name,
        :other => other_core_name
      }
    end

    def self.get_core_data_dir core_name
      result = Config.solr.get 'admin/cores', :params => {
        :action => 'STATUS',
        :core => core_name
      }

      result['status'][core_name]['dataDir']
    end

    def self.last_index_time_file core_name
      "last_index_time.#{File.basename(get_core_data_dir(core_name))}.txt"
    end

    def self.record_last_index_time core_name
      File.open(last_index_time_file(core_name), 'w') do |file|
        file << Time.now
      end
    end

    def self.last_index_time core_name
      filename = last_index_time_file(core_name)
      @@last_index_time ||=
        if File.exists?(filename)
          Time.parse(File.read(filename))
        else
          nil
        end
    end

    def self.initials given_name
      given_name.split(/[\s\-]+/).map { |name| name[0] }.join(" ")
    end

    def self.to_solr_content doc, citation_content
      index_str = ""

      if doc["published"]
        index_str << doc["published"]["year"].to_i.to_s if doc["published"]["year"]
      end

      index_str << " " + doc["title"] if doc["title"]

      if doc["journal"]
        journal = doc['journal']

        index_str << " " + journal["full_title"] if journal["full_title"]
        index_str << " " + journal["abbrev_title"] if journal["abbrev_title"]
      end

      if doc["proceedings"]
        index_str << " " + doc["proceedings"]["title"] if doc["proceedings"]["title"]
      end

      index_str << " " + doc["issue"] if doc["issue"]
      index_str << " " + doc["volume"] if doc["volume"]

      if doc["pages"]
        index_str << " " + doc["pages"]["first"] if doc["pages"]["first"]
        index_str << " " + doc["pages"]["last"] if doc["pages"]["last"]
      end

      if doc["contributors"]
        doc["contributors"].each do |c|
          if citation_content
            index_str << " " + c['given_name'] if c['given_name']
          else
            index_str << " " + initials(c["given_name"]) if c["given_name"]
          end
          index_str << " " + c["surname"] if c["surname"]
        end
      end

      index_str
    end

    def self.perform index_core_name, other_core_name
      puts "Indexing to #{index_core_name}"

      dois_coll = Config.collection 'dois'
      categories_coll = Config.collection 'categories'
      issns_coll = Config.collection 'issns'
      solr_core = Config.solr_core index_core_name
      solr_docs = []
      indexed_count = 0

      query = {}
      index_time = last_index_time(index_core_name)

      if index_time.nil?
        puts "First index. Performing full index."
      else
        puts "Indexing from #{index_time}."
        query[:updated_at] = {'$gt' => last_index_time(index_core_name)}
      end

      record_last_index_time(index_core_name)

      dois_coll.find(query, {:timeout => false}) do |cursor|
        cursor.each do |doc|
          if ["journal_article", "conference_paper"].include? doc["type"]
            solr_doc = {
              :doiKey => doc['doi'],
              :doi => doc['doi'],
              :content => to_solr_content(doc, true),
              :content_citation => to_solr_content(doc, false),
              :type => doc['type'],
              :category => [],
              :oa_status => 'Other'
            }
              
            # Publication year

            if doc.has_key?('published') && doc['published'].has_key?('year')
              solr_doc[:year] = doc['published']['year'].to_i
              solr_doc[:hl_year] = doc['published']['year'].to_i
            end
            
            # Publication name
            
            if doc.has_key? 'journal'
              if doc['journal'].has_key? 'full_title'
                solr_doc[:publication] = doc['journal']['full_title']
                solr_doc[:hl_publication] = doc['journal']['full_title']
              end
            elsif doc.has_key? 'proceedings'
              if doc['proceedings'].has_key? 'title'
                solr_doc[:publication] = doc['proceedings']['title']
                solr_doc[:hl_publication] = doc['proceedings']['title']
              end
            end

            # Category and OA status
            
            if doc['type'] == 'journal_article'
              query = []
              
              if doc['journal'].has_key? 'p_issn'
                query << {:p_issn => Helpers.normalise_issn(doc['journal']['p_issn'])}
              end
              
              if doc['journal'].has_key? 'e_issn'
                query << {:e_issn => Helpers.normalise_issn(doc['journal']['e_issn'])}
              end 
              
              unless query.empty?
                issn_record = issns_coll.find_one({'$or' => query})
                
                unless issn_record.nil? || issn_record['categories'].nil?
                  issn_record['categories'].each do |category_code|
                    category_record = categories_coll.find_one({:code => category_code})
                    solr_doc[:category] << category_record['name']
                  end
                end
                
                if !issn_record.nil? && issn_record['oa_info'] == 'doaj'
                  solr_doc[:oa_status] = 'Open Access'
                end
              end
            end

            if solr_doc[:category].empty?
              solr_doc[:category] << 'Not Specified'
            end

            # ISSN and ISBN
            
            if doc.has_key?('journal')
              if doc['journal'].has_key?('p_issn') || doc['journal'].has_key?('e_issn')
                solr_doc[:issn] = []
                if doc['journal'].has_key?('p_issn')
                  solr_doc[:issn] << Helpers.normalise_issn(doc['journal']['p_issn'])
                end
                if doc['journal'].has_key?('e_issn')
                  solr_doc[:issn] << Helpers.normalise_issn(doc['journal']['e_issn'])
                end
              end
            end
            
            solr_doc[:hl_volume] = doc['volume'] if doc.has_key? 'volume'
            solr_doc[:hl_issue] = doc['issue'] if doc.has_key? 'issue'
            solr_doc[:hl_title] = doc['title'] if doc.has_key? 'title'

            # Authors

            if doc.has_key? 'contributors'
              authors = doc['contributors'].map do |contributor|
                "#{contributor['given_name']} #{contributor['surname']}"
              end

              solr_doc[:hl_authors] = authors.join(', ')
            end
          
            solr_docs << solr_doc

            if solr_docs.count % 1000 == 0
              solr_core.add solr_docs
              solr_core.update :data => "<commit/>"
              solr_docs = []
              indexed_count = indexed_count + 1000
            end

          end
        end
      end

      if not solr_docs.empty?
        solr_core.add solr_docs
        solr_core.update :data => "<commit/>"
        indexed_count = indexed_count + solr_docs.count
      end

      puts "Indexing of #{index_core_name} complete."
      puts "Indexed #{indexed_count} documents (new or updated)."

      # Finally, we swap the newly indexed core with another.
      swap_cores(index_core_name, other_core_name)

      puts "Swapped #{index_core_name} with #{other_core_name}."
    end

  end

end
