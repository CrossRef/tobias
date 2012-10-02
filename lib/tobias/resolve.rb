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
        req.body = matched_citations.to_json
      end

      File.open('matches.txt', 'a') do |matches_file|
        File.open('non_matches.txt', 'a') do |non_matches_file|    
          JSON.parse(response.body).each do |match_info|
            if match_info['match']
              matches_file << "#{match_info['text']}\n"
              stats[:match_count] = stats[:match_count].next
            else
              non_matches_file << "#{match_info['text']}\n"
              stats[:non_match_count] = stats[:non_match_count].next
            end
          end
        end
      end
    end

    def self.perform file_path
      matched_citations = []
      stats = {
        :match_count => 0,
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

        if matched_citation.count >= 1000
          compare_matches(stats, matched_citations)
          matched_citations = []

          total = stats[:match_count] + stats[:non_match_count]
          puts "After #{total} comparisons:"
          puts "#{stats[:match_count]} matches"
          puts "#{stats[:non_match_count]} non-matches"
          puts "#{((stats[:match_count].to_f / total) * 100).to_i}% accuracy"
          puts "\n"
        end
      end
    end
  end

end
        
