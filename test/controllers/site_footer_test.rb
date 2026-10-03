require "test_helper"

# Component tier: the studio-engine site footer as Rantly renders it
# (config/initializers/studio.rb declares the facts; the engine draws them).
class SiteFooterTest < ActionDispatch::IntegrationTest
  PAGES = [ "/", "/?sort=discussed", "/rants/we-said-140-and-we-meant-it", "/@rantly", "/privacy", "/terms" ].freeze

  test "every page ends with exactly one site footer, after Rantly's own colophon" do
    PAGES.each do |path|
      get path
      assert_response :success
      assert_select "footer[data-site-footer]", 1, "#{path} should carry one site footer"
      assert_select "footer.colophon", 1, "#{path} keeps its demo colophon"
      assert_operator response.body.index("data-site-footer"), :>, response.body.index("class=\"colophon\""),
                      "#{path}: the engine footer comes after the colophon"
    end
  end

  test "the brand: wordmark, logo and tagline" do
    get root_path
    assert_select "footer[data-site-footer] .ftr-home[href=?]", "/" do
      assert_select "img.ftr-logo[src=?]", "/icon.svg"
      assert_select ".ftr-wordmark", "Rantly"
    end
    assert_select "footer[data-site-footer] .ftr-tagline",
                  "Let it all out. The social network with a 140-character minimum."
  end

  test "the link columns, in order, with their links" do
    get root_path
    headings = css_select("footer[data-site-footer] .ftr-col .ftr-heading").map { |h| h.text.strip }
    assert_equal %w[Contact Rantly About Legal], headings

    assert_select "footer[data-site-footer] nav[aria-label=Contact] a[href=?]", "mailto:team@mcritchie.studio", "team@mcritchie.studio"
    assert_select "footer[data-site-footer] nav[aria-label=Rantly]" do
      assert_select "a[href=?]", "/", "Latest rants"
      assert_select "a[href=?]", "/?sort=discussed", "Most discussed"
    end
    assert_select "footer[data-site-footer] nav[aria-label=About]" do
      assert_select "a[href=?][target=_blank]", "https://github.com/amcritchie/rantly", "The 2014 original"
      assert_select "a[href=?][target=_blank]", "https://mcritchie.studio/build", "Made with McRitchie Studio"
    end
    assert_select "footer[data-site-footer] nav[aria-label=Legal]" do
      assert_select "a[href=?]", privacy_path, "Privacy Policy"
      assert_select "a[href=?]", terms_path, "Terms of Service"
    end
  end

  test "the legal line and the copyright" do
    get root_path
    assert_select "footer[data-site-footer] .ftr-legal a[href=?]", privacy_path
    assert_select "footer[data-site-footer] .ftr-legal a[href=?]", terms_path
    assert_select "footer[data-site-footer] .ftr-copyright", "© #{Date.current.year} Rantly"
  end

  # Alex's footer brief: no address, map, phone, booking or social row.
  test "no address, map, phone, booking or social profiles" do
    get root_path
    assert_select "[data-footer-location]", 0
    assert_select "[data-footer-map]", 0
    assert_select "footer[data-site-footer] a[href^='tel:']", 0
    assert_select "[data-booking-popup], [data-studio-booking]", 0
    assert_select "footer[data-site-footer] .ftr-socials", 0
  end
end
