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
    ResultSet.new(
      address && JSON.parse(open(address_uri(address), "r:ASCII-8BIT").read)
    )
  end

  def self.draw(address, latitude, longitude)
    ResultSet.static(Coords.new(latitude, longitude, Address.parse(address)))
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

  class Address
    attr :street
    attr :house
    attr :city
    attr :country

    def self.parse(address)
      # we revert it and revert it back so we can safely extract the
      # house number first, and then everything else is the street name
      address.reverse =~ /^(?:((?:sib|[ab]p|[a-d])?\s*\d+)?\s+)?(.+)$/
      street, number = [$2 && $2.reverse, $1 && $1.reverse]

      new(street, number)
    end

    def initialize(street, house, city="Montevideo", country="Uruguay")
      @street  = street
      @house   = house
      @city    = city
      @country = country
    end

    def to_s
      "#{street} #{house}"
    end

    def to_uri
      CGI.escape([street  && "street:#{street}",
                  house   && "house:#{house}",
                  city    && "city:#{city}",
                  country && "country:#{country}"].compact.join(";"))
    end
  end

  class Coords
    attr :latitude
    attr :longitude
    attr :addresses

    def initialize(latitude, longitude, addresses)
      @latitude  = latitude
      @longitude = longitude
      @addresses = Array(addresses)
    end

    def multi?
      addresses.size > 1
    end

    def address
      addresses.first
    end

    def to_hash
      { latitude:  latitude,
        longitude: longitude,
        addresses: addresses.map(&:to_s) }
    end
  end

  class ResultSet
    attr :data

    def self.static(coords)
      new.tap do |set|
        set.coords.concat Array(coords)
      end
    end

    def initialize(data=nil)
      @data = data
    end

    def to_hash
      status = case coords.size
        when 0; "404"
        when 1; "200"
        else    "300"
      end

      { response_code: status, results: coords.map(&:to_hash) }
    end

    def exact_match?
      coords.size == 1
    end

    def empty?
      coords.empty?
    end

    def any?
      coords.any?
    end

    def each(&blk)
      coords.each(&blk)
    end

    def latitude
      raise "Too many choices" unless exact_match?
      coords.first.latitude
    end

    def longitude
      raise "Too many choices" unless exact_match?
      coords.first.longitude
    end

    def expanded
      expanded_coords = coords.map do |coord|
        coord.addresses.map do |address|
          Coords.new(coord.latitude, coord.longitude, [address])
        end
      end

      ResultSet.static(expanded_coords.flatten)
    end

    def coords
      @coords ||= begin
        raw = data ? data["features"] : []
        raw.map do |feature|
          addresses = feature["properties"].fetch("addr:housenumber").split(",").map do |house|
            Address.new(feature["properties"]["addr:street"], house)
          end

          Coords.new(
            feature["centroid"]["coordinates"].first,
            feature["centroid"]["coordinates"].last,
            addresses
          )
        end
      end
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
    %Q(<a href="#{url}">#{text}</a>).force_encoding("ASCII-8BIT")
  end

  def address_url(coord)
    "/geocode?" + [
      "address=#{CGI.escape(coord.address.to_s)}",
      "lat=#{CGI.escape(coord.latitude.to_s)}",
      "lng=#{CGI.escape(coord.longitude.to_s)}"
    ].join("&").force_encoding("ASCII-8BIT")
  end
end

Cuba.use Rack::Static, root: "public", urls: ["/css", "/js", "/img"]

Cuba.define do
  on get, path("") do
    res.redirect "/geocode"
  end

  on get, path("geocode"), param("address"), param("lat"), param("lng") do |address, lat, lng|
    if lat && lng
      result_set = Geocoder.draw(address, lat, lng)
    else
      result_set = Geocoder.find(address)
    end

    on accept("application/json") do
      res.write JSON.dump(result_set.to_hash)
    end

    on path("map.png"), param("size"), param("zoom") do |size, zoom|
      if result_set.exact_match?
        map = open(Geocoder.map(result_set.latitude, result_set.longitude, size || "400x300", zoom || 16))
        res["Content-Type"] = "image/png"
        res.write map.read
      elsif result_set.any?
        res.status = 300
      else
        res.status = 404
      end
    end

    on accept("text/javascript") do
      res["Content-Type"] = "text/html"
      res.write render("views/results.erb", results: result_set, address: address)
    end

    on default do
      res.write render("views/home.erb", results: result_set, address: address)
    end
  end

  on get, path("streets.json"), param("term") do |search|
    street = Geocoder::Address.parse(search).street
    comparer = Geocoder::StreetComparer.new(street)

    res["Content-Type"] = "application/json"
    res.write JSON.dump(comparer.matches)
  end
end
