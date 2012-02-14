# -*- coding: utf-8 -*-
require "uri"
require "net/http"

module URI
  class Generic

    def self.tld_dict
      path = File.join(File.dirname(__FILE__), "..", "..", "res", "tlds.txt")
      File.open(path, "r") do |file|
        dict_root = {}
        file.read.split(/\s+/).each do |domain|
          dict_node = dict_root
          domain.sub(/\A\./, "").split(".").reverse.each do |p|
            dict_node[p] ||= {}
            dict_node = dict_node[p]
          end
        end
        dict_root
      end
    end

    @@tld_dict = self.tld_dict

    # Returns a gTLD, ccTLD or, in the case of a ccTLD with
    # ccSLDs (such as .co.uk) returns both the ccSLD and ccTLD.
    def tld
      if not @tld.nil?
        @tld
      else
        dict = @@tld_dict
        parts = []
        host.split(".").reverse.each do |p|
          if dict.key? p
            parts << p
            dict = dict[p]
          else
            break
          end
        end
        @tld = parts.reverse.join "."
      end
    end

    # Returns the second (SLD) or third level domain. SLD
    # is returned if it is not a ccSLD, otherwise third level
    # domain is returned.
    def root
      @root ||= host.match(/\.?([^\.]+)\.#{tld.gsub(".", "\\.")}/)[1]
    end

    # Returns host name portion before root and tld.
    def sub
      if not @sub.nil?
        @sub
      else
        match = host.match(/\A(.+)\.#{root}/)
        if match.nil?
          @sub = ""
        else
          @sub = match[1]
        end
      end
    end

    # Returns one of :*_error, :other, :error  or :ok after attempts to
    # resolve the URI. Will follow redirects.
    def status limit=10, uri=self
      if limit.zero?
        {:status => :redirect_error}
      else
        begin
          response = Net::HTTP.start(uri.host, uri.port) do |http|
            request = Net::HTTP::Get.new uri.request_uri
            http.request request
          end
          
          case response
          when Net::HTTPSuccess then
            {:status => :ok}
          when Net::HTTPRedirection then
            status(limit - 1, uri.merge(response["Location"]))
          else
            {:status => :other, :code => response.code.to_i}
          end
        rescue SocketError => e
          {:status => :socket_error}
        rescue TimeoutError => e
          {:status => :timeout_error}
        rescue StandardError => e
          {:status => :error, :e => e}
        end
      end
    end
          
  end
end
