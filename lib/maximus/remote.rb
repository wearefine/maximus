require 'net/http'
require 'json'

module Maximus
  class Remote

    def initialize(url, output)
      uri = URI("http://localhost:3001/#{url}")
      req = Net::HTTP::Post.new(uri, initheader = {'Content-Type' =>'application/json'})
      req.body = output.to_json
      res = Net::HTTP.start(uri.hostname, uri.port) do |http|
        http.request(req)
      end
    end

  end
end