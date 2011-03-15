# encoding: UTF-8

require "./app"
require "cuba/test"

class Cutest::Scope
  def address(address, lat=nil, lng=nil)
    "/geocode?" + [
      "address=" + URI.escape(address),
      lat && "lat=" + URI.escape(lat),
      lng && "lng=" + URI.escape(lng)
    ].compact.join("&")
  end

  def geocodes_correctly?
    page.has_content?("Latitud:") &&
      page.has_content?("Longitud:") &&
      page.has_css?("img#static-map") &&
      page.status_code == 200
  end

  def ambiguous_address?
    page.has_content?("Múltiples resultados para") &&
      page.has_css?("ul#multiple-choices li") &&
      page.status_code == 200
  end

  def cant_find_address?
    page.has_css?("p.error") &&
      page.has_no_css?("ul#multiple-choices li") &&
      page.status_code == 200
  end

  def visit(*)
    super
  end
end

class Cuba::Ron
  def accept(mimetype)
    lambda do
      String(env["HTTP_ACCEPT"]).split(",").any? { |s| s.strip == mimetype } and
        res["Content-Type"] = mimetype
    end
  end
end

scope do
  test "Homepage redirects to /geocode" do
    visit "/"
    assert current_path == "/geocode"
  end

  test "Empty page loads fine" do
    visit "/geocode"
    assert page.status_code == 200
  end

  test "Page with a simple address loads fine" do
    visit address("Silvestre Blanco 2480")
    assert geocodes_correctly?
  end

  test "Page with a non-ASCII address loads fine" do
    visit address("Bulevar España 2529")
    assert geocodes_correctly?
  end

  test "Page with an ambiguous address loads fine" do
    visit address("Avenida 18 de Julio 1360")
    assert ambiguous_address?
  end

  test "Page with a non-existent address loads fine" do
    visit address("Silvestre Blanco 9999")
    assert cant_find_address?
  end
end

puts # Why doesn't cutest do this?
