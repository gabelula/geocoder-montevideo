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
  on get, path("") do
    res.redirect "/geocode"
  end

  on get, path("geocode"), param("address") do |address|
    locals = { address:   "",
               latitude:  "",
               longitude: "",
               results:   "" }

    if address
      data = JSON.parse(open(URL[address, "js"]).read)

      locals[:address] = address
      locals[:results] = data["found"]

      if data["found"] == 1
        locals[:latitude]  = data["bounds"][0][0]
        locals[:longitude] = data["bounds"][0][1]
      end
    end

    res.write render("views/home.erb", locals)
  end
end
