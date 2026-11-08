require "test_helper"

# Component tier: studio-engine's standard page header (studio/_page_header) and
# its legal page (studio/_legal_page), self-styled because Rantly builds no
# Tailwind (config/initializers/studio.rb). Each page has exactly one h1, a page
# that takes the header takes exactly one, and the row's own CSS and module come
# once per page.
class PageHeaderTest < ActionDispatch::IntegrationTest
  HEADER_PAGES = { "/" => "Rants", "/discussed" => "Rants", "/privacy" => "Privacy Policy", "/terms" => "Terms of Service" }.freeze
  CARD_PAGES = [ "/rants/we-said-140-and-we-meant-it", "/@rantly" ].freeze

  test "the initializer asks the engine for the self-styled header" do
    assert Studio.page_header_self_styled, "config.page_header_self_styled is off: the row would render unstyled"
  end

  test "a page with the header has one header, one h1 in it, and its assets once" do
    HEADER_PAGES.each do |path, title|
      get path
      assert_response :success
      assert_select ".page-header", 1, "#{path}: one page header"
      assert_select "h1", 1, "#{path}: one h1"
      assert_select ".page-header h1.page-header-title", title
      assert_select ".page-header-sentinel", 1
      assert_select "script[type=module][src*='studio/page_header_self_styled']", 1, "#{path}: the header's module, once"
      assert_equal 1, css_select("style").count { |s| s.text.include?(".page-header[data-stuck]") }, "#{path}: the header's CSS, once"
      # The masthead is the document's first <header>, so the module pins the row under it.
      assert_equal "masthead", css_select("header").first["class"], "#{path}: the first <header> must stay the masthead"
    end
  end

  # The served sheet, not the source: the row's no-script fallback and the legal
  # hover pin must reach the browser (test/system/page_header_test.rb measures them).
  test "the served stylesheet sets --nav-h on :root and pins the legal link hover" do
    get "/privacy"
    href = css_select("link[rel=stylesheet]").map { |l| l["href"] }.find { |h| h.include?("/app") }
    assert href, "the layout links Rantly's sheet"
    get href
    assert_response :success
    root = response.body[/^:root\s*\{.*?^\}/m]
    assert_match(/--nav-h:\s*61px;/, root, "the :root block sets the masthead's height for the stuck row")
    assert_match(/\.legal-page-body a:hover\s*\{\s*color:\s*var\(--color-primary-ink\);\s*\}/, response.body)
  end

  test "the rant and profile pages keep their h1 in the card and take no header" do
    CARD_PAGES.each do |path|
      get path
      assert_response :success
      assert_select "h1", 1, "#{path}: one h1"
      assert_select ".page-header", 0
      assert_select "script[src*='page_header_self_styled']", 0
    end
  end

  test "the feed's sorts are the header's tabs, the current one marked" do
    get root_path
    assert_select ".page-header nav.page-header-tabs[aria-label=?]", "Sort the feed" do
      assert_select "a.page-header-tab", 2
      assert_select "a.btn-primary[aria-current=page][href=?]", "/", "Latest"
      assert_select "a.btn-neutral:not([aria-current])[href=?]", "/discussed", "Most discussed"
    end
    assert_select "nav.tabs", 0, "the old tab strip is gone"
    assert_select "h1.visually-hidden", 0, "the hidden h1 is gone"
  end

  test "the legal pages are the engine's legal page: header, date, column, the other page linked" do
    { "/privacy" => [ "privacy", "/terms", "Terms of Service" ], "/terms" => [ "terms", "/privacy", "Privacy Policy" ] }.each do |path, (key, other, label)|
      get path
      assert_select "div.legal-page[data-studio-legal-page][data-legal-page=?]", key, 1 do
        assert_select "> .page-header h1"
        assert_select "> .page-header .page-header-links a[href=?]", other, label
        assert_select "> p.legal-page-updated", "Last updated October 3, 2026"
        assert_select "> article.legal-page-body > section > h2", minimum: 8
      end
      assert_select "article.card.legal, .legal__head, .legal__title", 0, "#{path}: the old card markup is gone"
    end
  end
end
