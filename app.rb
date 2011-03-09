require "cgi"
require "cuba"
require "json"
require "open-uri"

API_KEY = ENV["API_KEY"]

abort "Please set an API_KEY environment variable with your CloudMade API key" if API_KEY.nil?

module Geocoder
  URL = "http://geocoding.cloudmade.com/%s/geocoding/v2/find.js"

  def self.find(address)
    lat_long = address ? LatLong.new(JSON.parse(open(uri(address)).read)) : LatLong.new
    Response.new(address, lat_long)
  end

  def self.uri(address, api_key=API_KEY)
    URI.parse(URL % api_key).tap do |url|
      url.query = "query=" + Address.parse(address).to_uri
    end
  end

  class Address < Struct.new(:street, :house, :city, :country)
    def self.parse(address)
      address =~ /(.+)\s(\d+.+)/
      new($1, $2, "Montevideo", "Uruguay")
    end

    def to_uri
      CGI.escape([street  && "street:#{street}",
                  house   && "house:#{house}",
                  city    && "city:#{city}",
                  country && "country:#{country}"].compact.join(";"))
    end
  end

  class LatLong
    attr :data

    def initialize(data=nil)
      @data = data
    end

    def latitude
      exact_match? && data["bounds"][0][0]
    end

    def longitude
      exact_match? && data["bounds"][0][1]
    end

    def to_hash
      if exact_match?
        { response_code: "200",
          latitude:      latitude,
          longitude:     longitude }
      else
        { response_code: "404" }
      end
    end

    def exact_match?
      data && data["bounds"][0] == data["bounds"][1]
    end
  end

  class Response
    attr :address
    attr :lat_long

    def initialize(address, lat_long)
      @address, @lat_long = address, lat_long
    end

    def to_json
      JSON.dump(lat_long.to_hash.merge(address: address))
    end

    def to_hash
      { address: address, lat_long: lat_long }
    end
  end
end

Cuba.use Rack::Static, root: "public", urls: ["/css", "/js"]

Cuba.define do
  on get, path("") do
    res.redirect "/geocode"
  end

  on get, path("geocode"), param("address") do |address|
    response = Geocoder.find(address)

    on accept("application/json") do
      res.write response.to_json
    end

    on default do
      res.write render("views/home.erb", response.to_hash)
    end
  end
end
