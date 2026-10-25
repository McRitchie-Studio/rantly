require "test_helper"
require "static_site"

# Unit tier: the static build (lib/static_site.rb). It renders every page through
# the real Rack app, so these tests read the files it wrote, not the controllers.
class StaticSiteTest < ActiveSupport::TestCase
  HOST = "rantly.mcritchie.studio".freeze

  setup do
    @out = Dir.mktmpdir("rantly-static")
    @manifest = StaticSite::Builder.new(out: @out, host: HOST).build
  end

  teardown { FileUtils.rm_rf(@out) }

  def page(path) = File.read(File.join(@out, path))

  test "every route the sample data names is a file, at its pretty-URL directory" do
    expected = [ "index.html", "discussed/index.html", "privacy/index.html", "terms/index.html", "up/index.html" ] +
      SampleData.current.rants.map { |rant| "rants/#{rant.id}/index.html" } +
      SampleData.current.users.map { |user| "@#{user.handle}/index.html" }
    expected.each { |path| assert File.file?(File.join(@out, path)), "#{path} was not written" }
    assert_equal expected.sort, @manifest.keys.grep(/index\.html\z/).sort
  end

  test "a page is what the app serves at that path" do
    rant = SampleData.current.rants.first
    assert_includes page("rants/#{rant.id}/index.html"), "<title>#{ERB::Util.h(rant.title)} · Rantly</title>"
    assert_includes page("discussed/index.html"), %(aria-current="page" href="/discussed")
  end

  test "/up is in the bundle, so the ship's smoke reads 200 from the static host" do
    assert_match(/<body[^>]*>/, page("up/index.html"))
    assert_equal "text/html", @manifest.fetch("up/index.html").fetch("content_type")
  end

  test "every stylesheet, script and module the pages name is in the bundle, digested" do
    css = @manifest.keys.grep(%r{\Aassets/.+-[0-9a-f]{8,}\.css\z})
    js = @manifest.keys.grep(%r{\Aassets/.+-[0-9a-f]{8,}\.js\z})
    assert css.any?, "no digested stylesheet in #{@manifest.keys}"
    assert js.any? { |key| key.include?("composer") }, "the composer module is missing: #{js}"
    assert_includes @manifest.keys, "icon.svg"
    assert_includes @manifest.keys, "404.html"
  end

  test "no page links a query string or a path the bundle does not hold" do
    @manifest.each_key.select { |key| key.end_with?(".html") }.each do |key|
      StaticSite::Links.internal(page(key), base: "/", host: HOST).each do |url|
        path = URI(url).path
        target = StaticSite::Builder.file_for(path, html: !File.extname(path).present?)
        assert @manifest.key?(target) || @manifest.key?(StaticSite::Builder.file_for(path, html: false)),
          "#{key} links #{url}, which is not in the bundle"
      end
    end
  end

  test "the manifest records each file's size and sha256, as the hub's bundle manifest does" do
    entry = @manifest.fetch("index.html")
    bytes = File.binread(File.join(@out, "index.html"))
    assert_equal bytes.bytesize, entry["size"]
    assert_equal Digest::SHA256.hexdigest(bytes), entry["sha256"]
  end
end

# The refusals: a link a static host cannot serve stops the build.
class StaticSiteRefusalTest < ActiveSupport::TestCase
  FakeApp = Struct.new(:pages) do
    def call(env)
      path = env["PATH_INFO"]
      body = pages[path]
      return [ 404, { "content-type" => "text/html" }, [ "nope" ] ] unless body

      [ 200, { "content-type" => "text/html; charset=utf-8" }, [ body ] ]
    end
  end

  def build(pages)
    Dir.mktmpdir do |out|
      StaticSite::Builder.new(out: out, host: "x.test", app: FakeApp.new(pages), seeds: [ "/", "/up" ]).build
    end
  end

  test "a link with a query string is refused, naming the page" do
    error = assert_raises(StaticSite::Error) do
      build("/" => %(<a href="/?sort=x">x</a>), "/up" => "<body>ok</body>")
    end
    assert_match %r{/ links /\?sort=x}, error.message
  end

  test "a link to a page the app does not serve is refused" do
    error = assert_raises(StaticSite::Error) do
      build("/" => %(<a href="/gone">x</a>), "/up" => "<body>ok</body>")
    end
    assert_match %r{/gone answered 404 \(linked from /\)}, error.message
  end

  test "external links, mailto and fragments are left alone" do
    manifest = build("/" => %(<a href="https://github.com/x">g</a><a href="mailto:a@b.c">m</a><a href="#main">s</a>),
                     "/up" => "<body>ok</body>")
    assert_equal [ "index.html", "up/index.html" ], manifest.keys.sort
  end

  test "a bare own-host link is the root, fetched once" do
    calls = []
    app = FakeApp.new({ "/" => %(<a href="https://x.test">home</a>), "/up" => "<body>ok</body>" })
    counting = ->(env) { calls << env["PATH_INFO"]; app.call(env) }
    Dir.mktmpdir do |out|
      StaticSite::Builder.new(out: out, host: "x.test", app: counting, seeds: [ "/", "/up" ]).build
    end
    assert_equal [ "/", "/up" ], calls
  end

  test "an own-host absolute link is followed like a relative one" do
    manifest = build("/" => %(<a href="https://x.test/about">a</a>), "/up" => "<body>ok</body>",
                     "/about" => "<p>about</p>")
    assert_includes manifest.keys, "about/index.html"
  end
end
