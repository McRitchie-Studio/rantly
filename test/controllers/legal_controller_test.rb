require "test_helper"

# Component tier: the Privacy Policy and Terms of Service, and the facts about
# the site that the Privacy Policy states. Each "the policy says" test pins a
# practice to what the app actually does, so the day the app changes the
# practice, this fails and points at app/views/legal/privacy.html.erb.
class LegalControllerTest < ActionDispatch::IntegrationTest
  PAGES = [ "/", "/?sort=discussed", "/rants/we-said-140-and-we-meant-it", "/@rantly", "/privacy", "/terms" ].freeze

  test "the Privacy Policy names the operator and the date" do
    get privacy_path
    assert_response :success
    assert_select "title", "Privacy Policy · Rantly"
    assert_select "article[data-legal-page=privacy] h1", "Privacy Policy"
    assert_select ".legal__updated", /Last updated: \w+ \d+, \d{4}/
    assert_match "McRitchie Studio LLC, doing business as McRitchie Studio", response.body
    assert_select "a[href=?]", "mailto:team@mcritchie.studio"
  end

  test "the Terms of Service name the operator and link the policy" do
    get terms_path
    assert_response :success
    assert_select "title", "Terms of Service · Rantly"
    assert_select "article[data-legal-page=terms] h1", "Terms of Service"
    assert_match "McRitchie Studio LLC, doing business as McRitchie Studio", response.body
    assert_select "article a[href=?]", privacy_path, "Privacy Policy"
  end

  test "the policy says no cookies: no page sets one" do
    PAGES.each do |path|
      get path
      assert_nil response.headers["set-cookie"], "#{path} set a cookie; the Privacy Policy says none"
    end
  end

  test "the policy says nothing you type is sent: no page has a form" do
    PAGES.each do |path|
      get path
      assert_select "form", 0, "#{path} has a form; the Privacy Policy says nothing is sent"
      assert_select "input[type=password], input[type=email]", 0, "#{path} asks for credentials"
    end
  end

  test "the policy says the pages load nothing from other companies" do
    PAGES.each do |path|
      get path
      sources = css_select("script[src], link[href][rel=stylesheet], link[rel=modulepreload], img[src], iframe[src]")
                .map { |node| node["src"] || node["href"] }
      external = sources.select { |src| src.start_with?("http:", "https:", "//") }
      assert_empty external, "#{path} loads from another origin; the Privacy Policy says it does not"
      assert_select "[data-footer-map]", 0, "#{path}: the footer map would fetch OpenStreetMap tiles"
    end
  end
end
