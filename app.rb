require "cgi"
require "cuba"
require "json"
require "open-uri"
require "text"
require "yaml"

API_KEY = ENV.fetch("API_KEY") do
  abort "Please set an API_KEY environment variable with your CloudMade API key"
end

module Geocoder
  GEOCODE_URL = "http://geocoding.cloudmade.com/%s/geocoding/v2/find.js"
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

  def self.map(latitude, longitude, size, zoom=16, api_key=API_KEY)
    Map.new(latitude, longitude, size, zoom, api_key).to_uri
  end

  class Map < Struct.new(:latitude, :longitude, :size, :zoom, :api_key)
    URL    = "http://staticmaps.cloudmade.com/%s/staticmap"
    MARKER = "http://tile.cloudmade.com/wml/0.2/images/marker.png"

    def center
      CGI.escape("#{latitude},#{longitude}")
    end

    def size
      user_size = super.to_s.split("x").map(&:to_i)
      user_size = user_size.map { |dim| [dim.abs, 1600].min }
      user_size = user_size.size == 1 ? user_size * 2 : user_size
      user_size.join("x")
    end

    def zoom
      [1, [18, super.to_i].min].max.to_s
    end

    def marker
      CGI.escape("url:#{MARKER}|#{latitude},#{longitude}")
    end

    def to_uri
      (URL % api_key) + "?" + [
        "center=#{center}",
        "size=#{size}",
        "zoom=#{zoom}",
        "marker=#{marker}"
      ].join("&")
    end
  end

  class Address < Struct.new(:street, :house, :city, :country)
    def self.parse(address)
      # we revert it and revert it back so we can safely extract the
      # house number first, and then everything else is the street name
      address.reverse =~ /^(?:((?:sib|[ab]p|[a-d])?\s*\d+)?\s+)?(.+)$/
      street, number = [$2 && $2.reverse, $1 && $1.reverse]

      new(street, number, "Montevideo", "Uruguay")
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

    def to_a
      [latitude, longitude]
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

  class StreetComparer
    attr :term
    attr :streets

    def initialize(term, streets=STREETS)
      @term = sanitize(term)
      @streets = streets
    end

    def matches
      term_sounds_like = term.map { |word| sounds(word) }.flatten.compact
      scored = streets.map do |street|
        street_sounds_like = sanitize(street).map { |word| sounds(word) }.flatten.compact
        [street, (street_sounds_like & term_sounds_like).size]
      end

      scored.sort {|a,b| b.last <=> a.last }.first(7).map(&:first)
    end

    private

    def sanitize(street)
      street.strip.split(/\s+/)
    end

    def sounds(word)
      Text::Metaphone.double_metaphone(word)
    end
  end
end

class Cuba::Ron
  def link(text, url=text)
    %Q(<a href="#{url}">#{text}</a>)
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

    on path("map.png"), param("size"), param("zoom") do |size, zoom|
      lat, lng = response.lat_long.to_a
      map = open(Geocoder.map(lat, lng, size || "400x300", zoom || 16))

      res["Content-Type"] = "image/png"
      res.write map.read
    end

    on default do
      res.write render("views/home.erb", response.to_hash)
    end
  end

  on get, path("streets.txt"), param("q") do |search|
    street = Geocoder::Address.parse(search).street
    comparer = Geocoder::StreetComparer.new(street)

    res["Content-Type"] = "text/plain"
    res.write comparer.matches.join("\n")
  end
end
