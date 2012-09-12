module Tobias
  module Helpers

    def self.normalise_issn s
      s = s.upcase.gsub /[^0-9X]/, ''
      "#{s[0, 4]}-#{s[4, 7]}"
    end

  end
end
