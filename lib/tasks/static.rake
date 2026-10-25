# bin/rails static:build — render every page to plain files (lib/static_site.rb).
#   OUT   the directory to write (default tmp/static/site); it is emptied first
#   HOST  the host the pages are built for (default rantly.mcritchie.studio)
# The manifest (path => size, sha256, content_type) is written beside OUT, never
# inside it, so it is not served. Run it through bin/static-build, which builds
# the digested assets first.
namespace :static do
  desc "Render every Rantly page to static files"
  task build: :environment do
    require "static_site"

    out = Rails.root.join(ENV.fetch("OUT", "tmp/static/site"))
    host = ENV.fetch("HOST", "rantly.mcritchie.studio")
    manifest = StaticSite::Builder.new(out: out, host: host).build
    File.write("#{out}.manifest.json", JSON.pretty_generate(manifest))
    bytes = manifest.values.sum { |entry| entry["size"] }
    puts "static: #{manifest.size} files, #{bytes} bytes -> #{out}"
  rescue StaticSite::Error => e
    abort "static: #{e.message}"
  end
end
