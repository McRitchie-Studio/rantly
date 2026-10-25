require "digest"
require "fileutils"
require "json"
require "nokogiri"
require "rack/mock"
require "uri"

# The static build: every page Rantly serves, rendered once to plain files, so a
# host with no Ruby (Cloudflare R2) can serve the site. The hub's release ship
# runs it at the frozen SHA (bin/static-build) and uploads the directory; see the
# hub's docs/agents/modules/static-cloudflare.md.
#
# It renders through the REAL Rack app, so a page in the bundle is byte for byte
# what the dynamic app answers, and it CRAWLS from the seeds: every internal href,
# src, importmap entry and CSS url() is fetched too. Two kinds of link stop the
# build, because a static host cannot answer them:
#   - a query string (/?sort=x): the host ignores it, so the page would be wrong
#   - a path the app does not answer 200 (a 404, or a redirect)
#
# The output is the directory-index layout every static host understands:
#   /                -> index.html
#   /rants/some-id   -> rants/some-id/index.html   (a page: text/html, no extension)
#   /assets/app-1a2b.css -> assets/app-1a2b.css     (anything with an extension)
#
#   StaticSite::Builder.new(out: "tmp/static/site", host: "rantly.mcritchie.studio").build
#   # => { "index.html" => { "size" =>, "sha256" =>, "content_type" => }, ... }
module StaticSite
  class Error < StandardError; end

  # The seed paths: every route, enumerated from the sample data, so a rant or a
  # user no page happens to link is still built.
  def self.seeds(data = SampleData.current)
    [ "/", "/discussed", "/privacy", "/terms", "/up", "/404.html", "/icon.png", "/icon.svg", "/robots.txt" ] +
      data.rants.map { |rant| "/rants/#{rant.id}" } +
      data.users.map { |user| "/@#{user.handle}" }
  end

  # The internal URLs a page or stylesheet names, as absolute paths (a query is
  # kept, so the builder can refuse it; a fragment is dropped).
  module Links
    module_function

    def internal(body, base:, host:, css: false)
      raw = css ? css_urls(body) : html_urls(body)
      raw.filter_map { |ref| resolve(ref, base, host) }.uniq
    end

    def html_urls(body)
      doc = Nokogiri::HTML5(body)
      urls = doc.css("a[href], link[href]").map { |node| node["href"] }
      urls += doc.css("script[src], img[src], source[src], video[src], audio[src]").map { |node| node["src"] }
      urls += doc.css("img[srcset], source[srcset]").flat_map { |node| node["srcset"].split(",").map { |part| part.strip.split(/\s+/).first } }
      doc.css("script[type=importmap]").each do |node|
        map = JSON.parse(node.text) rescue {}
        urls += Array(map["imports"]&.values)
      end
      doc.css("style").each { |node| urls += css_urls(node.text) }
      urls.compact
    end

    def css_urls(body)
      body.scan(/url\(\s*['"]?([^'")]+)['"]?\s*\)/).flatten +
        body.scan(/@import\s+['"]([^'"]+)['"]/).flatten
    end

    def resolve(ref, base, host)
      ref = ref.to_s.strip
      return nil if ref.empty? || ref.start_with?("#", "data:", "mailto:", "tel:", "javascript:")

      uri = URI.join("https://#{host}#{base}", ref)
      return nil unless %w[http https].include?(uri.scheme) && uri.host == host

      path = uri.path.empty? ? "/" : uri.path
      uri.query ? "#{path}?#{uri.query}" : path
    rescue URI::Error
      nil
    end
  end

  class Builder
    # The file a path is written to. A page (HTML) with no extension gets a
    # directory of its own, so /rants/x and /rants/x/ both find it.
    def self.file_for(path, html:)
      clean = path.sub(%r{\A/+}, "").sub(%r{/+\z}, "")
      return "index.html" if clean.empty?
      return "#{clean}/index.html" if html && File.extname(clean).empty?

      clean
    end

    def initialize(out:, host:, app: Rails.application, seeds: StaticSite.seeds)
      @out = out.to_s
      @host = host
      @app = app
      @seeds = seeds
    end

    def build
      FileUtils.rm_rf(@out)
      FileUtils.mkdir_p(@out)
      manifest = {}
      queue = @seeds.map { |path| [ path, nil ] }
      seen = {}

      until queue.empty?
        path, from = queue.shift
        next if seen[path]

        seen[path] = true
        refuse_query!(path, from)
        status, type, body = fetch(path)
        unless status == 200
          raise Error, "#{path} answered #{status}#{from ? " (linked from #{from})" : ''}: " \
                       "a static host can only serve what the app answers 200"
        end

        html = type.start_with?("text/html")
        file = self.class.file_for(path, html: html)
        write(file, body)
        manifest[file] = { "size" => body.bytesize, "sha256" => Digest::SHA256.hexdigest(body), "content_type" => type }

        next unless html || type.start_with?("text/css")

        Links.internal(body, base: path, host: @host, css: !html).each do |link|
          refuse_query!(link, path)
          queue << [ link, path ]
        end
      end

      manifest.sort.to_h
    end

    private

    def refuse_query!(link, from)
      return unless link.include?("?")

      raise Error, "#{from || 'a seed'} links #{link}: a static host ignores the query string, " \
                   "so give that page a path of its own"
    end

    def fetch(path)
      env = Rack::MockRequest.env_for("https://#{@host}#{path}", "HTTP_HOST" => @host, "HTTPS" => "on")
      status, headers, body = @app.call(env)
      text = +""
      body.each { |chunk| text << chunk }
      body.close if body.respond_to?(:close)
      type = (headers["content-type"] || headers["Content-Type"]).to_s.split(";").first.to_s.strip
      [ status.to_i, type, text.b ]
    end

    def write(file, body)
      target = File.join(@out, file)
      raise Error, "#{file} escapes the output directory" unless File.expand_path(target).start_with?(File.expand_path(@out) + "/")

      FileUtils.mkdir_p(File.dirname(target))
      File.binwrite(target, body)
    end
  end
end
