# -*- coding: utf-8 -*-
require_relative 'tasks'
require_relative 'config'

require 'csv'
require 'faraday'
require 'json'

module Tobias

  CMS_CONN = Faraday.new(:url => 'http://search.labs.crossref.org')

  class CompareDoiMatch < ConfigTask
    def self.compare_matches stats, matched_citations
      response = CMS_CONN.post do |req|
        req.url '/links'
        req.body = matched_citations.map { |c| c[0] }.to_json
      end

      File.open('matches.txt', 'a') do |matches_file|
        File.open('non_matches.txt', 'a') do |non_matches_file|    
          File.open('false_matches.txt', 'a') do |false_matches_file|
            results = JSON.parse(response.body)['results']
            results.each_index do |index|
              result = results[index]
              
              if result['match'] 
                result_doi = result['doi'].downcase
                expected_doi = matched_citations[index][1].downcase
                
                if result_doi == expected_doi
                  matches_file << "#{result['text']}\n"
                  stats[:match_count] = stats[:match_count].next
                else
                  false_matches_file << "#{result['text']}\n"
                  stats[:false_match_count] = stats[:false_match_count].next
                end
              else
                non_matches_file << "#{result['text']}\n"
                stats[:non_match_count] = stats[:non_match_count].next
              end
            end
          end
        end
      end
    end

    def self.perform file_path
      matched_citations = []
      stats = {
        :match_count => 0,
        :false_match_count => 0,
        :non_match_count => 0
      }
      
      CSV.foreach(file_path) do |row|
        citation_text = row[3]
        matched_doi = row[4]

        unless citation_text.empty? || matched_doi.empty?
          # For each citation that has a full text and matched
          # DOI, add it to a list of those that we will attempt
          # to match using CrossRef Metadata Search.
          matched_citations << [citation_text, matched_doi]
        end

        if matched_citations.count >= 10
          compare_matches(stats, matched_citations)
          matched_citations = []

          total = stats[:match_count] + stats[:non_match_count] + stats[:false_match_count]
          puts "After #{total} comparisons:"
          puts "#{stats[:match_count]} matches"
          puts "#{stats[:false_match_count]} false positive matches"
          puts "#{stats[:non_match_count]} non-matches"
          puts "#{stats[:match_count].to_f / total} correct match chance"
          puts "\n"
        end
      end
    end
  end

end
        
