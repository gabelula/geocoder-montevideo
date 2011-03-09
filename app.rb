require "cgi"
require "cuba"
require "json"
require "open-uri"

API_KEY = "f8c0606a56b441db908b280bcdc91d01";

URL = ->(address, format="js") {
  address = address.gsub(/(.+)\s(\d+.+)/, '\2 \1').gsub(/\s+/, '+') # cloudmade expects <number> <street>
  URI.parse("http://geocoding.cloudmade.com/#{API_KEY}/geocoding/v2/find.#{format}").tap do |url|
    url.query = "query=" + CGI.escape("#{address};city:Montevideo;country:UY")
  end
}

Cuba.define do
  on get, path("geocode"), param("address") do |address|
    data = JSON.parse(open(URL[address, "js"]).read)

    if data["found"].nil? || data["found"] == 0
      res.write "No results"
    elsif data["found"] == 1
      res.write "lat: #{data["bounds"][0][0]}; long: #{data["bounds"][0][1]}"
    else
      res.write "Multiple results"
    end
  end
end
