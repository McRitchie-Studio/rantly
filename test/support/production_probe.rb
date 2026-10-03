# Run by ProductionSslTest under `bin/rails runner -e production`: sends the
# requests Heroku's router forwards (X-Forwarded-Proto says what the visitor
# typed) through the real production middleware stack and prints what came
# back, one JSON object keyed "<proto> <path>". "footer" says whether the page
# carried the engine's site footer; "eager_loaded" that production eager-loaded
# the app (with studio-engine in the bundle) and still booted.
require "json"

requests = [ %w[http /], %w[http /up], %w[https /], %w[https /up],
             %w[https /privacy], %w[https /terms], %w[https /login] ]
results = requests.to_h do |proto, path|
  env = Rack::MockRequest.env_for("http://rantly.mcritchie.studio#{path}",
    "HTTP_X_FORWARDED_PROTO" => proto, "REMOTE_ADDR" => "10.1.2.3")
  status, headers, body = Rails.application.call(env)
  html = +""
  body.each { |chunk| html << chunk }
  body.close if body.respond_to?(:close)
  [ "#{proto} #{path}", { "status" => status, "location" => headers["location"], "set_cookie" => headers["set-cookie"],
                          "footer" => html.include?("data-site-footer") } ]
end
results["eager_loaded"] = Rails.application.config.eager_load

puts JSON.generate(results)
