require "cgi"
require "cuba"
require "json"
require "open-uri"
require "yaml"

API_KEY = ENV["API_KEY"]

abort "Please set an API_KEY environment variable with your CloudMade API key" if API_KEY.nil?

module Geocoder
  GEOCODE_URL = "http://geocoding.cloudmade.com/%s/geocoding/v2/find.js"
  MAP_URL     = "http://staticmaps.cloudmade.com/%s/staticmap"
  STREETS     = YAML.load_file(File.expand_path("../data/streets.montevideo.yml", __FILE__))

  def self.find(address)
    lat_long = if address
      data = JSON.parse(open(address_uri(address)).read)
      LatLong.new(data)
    else
      LatLong.new
    end

    Response.new(address, lat_long)
  end

  def self.address_uri(address, api_key=API_KEY)
    URI.parse(GEOCODE_URL % api_key).tap do |url|
      url.query = "query=" + Address.parse(address).to_uri
    end
  end

  def self.map(latitude, longitude, api_key=API_KEY)
    (MAP_URL % api_key) + "?" + [
      "center=#{latitude},#{longitude}",
      "size=977x272",
      "zoom=16",
      "marker=url:http://tile.cloudmade.com/wml/0.2/images/marker.png|#{latitude},#{longitude}"
    ].join("&")
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

Cuba.use Rack::Static, root: "public", urls: ["/css", "/js", "/img"]

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

  on get, path("streets.json") do
    res["Content-Type"] = "application/json"
    res.write JSON.dump(Geocoder::STREETS)
  end
end
