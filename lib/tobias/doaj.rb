# -*- coding: utf-8 -*-
require 'open-uri'

require_relative 'tasks'
require_relative 'config'
require_relative 'helpers'

module Tobias
  
  class DoajScrapeTask < ConfigTask
    
    BY_TITLE_BASE_URL = 'http://www.doaj.org/doaj?func=byTitle'
    BY_TITLE_LETTER_PARAM = 'query'
    BY_TITLE_PAGE_PARAM = 'p'

    ISSN_EISSN_SCAN = /<b>ISSN<\/b>:\s[0-9]{7}[0-9X]\s+<br><b>EISSN<\/b>:\s[0-9]{7}[0-9X]/
    ISSN_ONLY_SCAN = /<b>ISSN<\/b>:\s[0-9]{7}[0-9X]\s+<br><b>Subject<\/b>/

    def self.issns_on_page url
      page = open(url).read

      # Find records that have both pissn and eissn
      issns = page.scan(ISSN_EISSN_SCAN).map do |m|
        issns = m.scan /[0-9]{7}[0-9X]/
        {
          :p_issn => Helpers.normalise_issn(issns.first),
          :e_issn => Helpers.normalise_issn(issns.last)
        }
      end

      # Find records that have only a pissn
      page.scan(ISSN_ONLY_SCAN).each do |m|
        issns << {:p_issn => Helpers.normalise_issn(m.scan(/[0-9]{7}[0-9X]/).first)}
      end

      issns
    end

    def self.insert_issns issns
      issns_coll = Config.collection 'issns'

      issns.each do |issn_record|
        [:p_issn, :e_issn].each do |issn_type|
          if issn_record.has_key? issn_type
            query = {issn_type => issn_record[issn_type]}
            update = {'$set' => {:oa_info => 'doaj'}}
            issns_coll.update(query, update, {:upsert => true})
          end
        end
      end
    end

    def self.perform
      ('A'..'Z').each do |letter|
        start_url = "#{BY_TITLE_BASE_URL}&#{BY_TITLE_LETTER_PARAM}=#{letter}"

        # Iterate with page numbers until we get no ISSNs back, which signifies
        # the end of paging.
        end_reached = false
        page_number = 1
        next_url = start_url
        issns = []

        while !end_reached
          issn_records = issns_on_page next_url

          puts "Processed letter #{letter}, page #{page_number}, found #{issn_records.count}"
          
          if issn_records.empty?
            end_reached = true
          else
            page_number = page_number.next
            next_url = "#{start_url}&#{BY_TITLE_PAGE_PARAM}=#{page_number.to_s}"

            issns = issns + issn_records
          end
        end

        insert_issns issns
      end
    end

  end
end
        
