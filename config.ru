require "uri"
require "./app"

class Redirector
  def initialize(app, domain_with_port=nil, status=301)
    @app = app
    @domain, @port = domain_with_port.to_s.split(":")
    @port ||= 80
    @status = status
  end

  def call(env)
    if matches?(env)
      @app.call(env)
    else
      body = "Redirecting to #{uri(env)}..."

      headers = {
        "Location"       => uri(env),
        "Content-Length" => body.size.to_s
      }

      [@status, headers, [body]]
    end
  end

  def matches?(env)
    @domain.nil? || (env["HTTP_HOST"] == @domain && env["SERVER_PORT"].to_i == @port)
  end

  def uri(env)
    URI::HTTP.build([
      env["rack.url_scheme"],
      @domain,
      @port,
      env["SCRIPT_NAME"] + env["PATH_INFO"],
      env["QUERY_STRING"],
      nil
    ]).to_s
  end
end

if ENV["RACK_ENV"] == "production"
  use Redirector, "acavamos.com"
end

run Cuba
