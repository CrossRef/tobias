module Tobias
  module Helpers

    def self.normalise_issn s
      s = s.upcase.gsub /[^0-9X]/, ''
      "#{s[0, 4]}-#{s[4, 7]}"
    end

    def self.noramlise_doi s
      if s[7,2] == '//'
        s.downcase.sub(/\/\//, '/')
      else
        s.downcase
      end
    end

  end
end
