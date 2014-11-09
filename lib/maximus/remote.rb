require 'net/http'

module Maximus
  module Remote

    def remote(name, url, output)
      uri = URI("http://localhost:3001/#{url}")
      req = Net::HTTP::Post.new(uri, initheader = {'Content-Type' =>'application/json'})
      req.basic_auth 'user54', 'pass77'
      req.body = output.to_json
      res = Net::HTTP.start(uri.hostname, uri.port) do |http|
        http.request(req)
      end
    end

  end
end