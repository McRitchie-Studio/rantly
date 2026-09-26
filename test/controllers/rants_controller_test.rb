require "test_helper"

# Component tier: the feed and a single rant as rendered HTML.
class RantsControllerTest < ActionDispatch::IntegrationTest
  test "/up answers 200 with no database" do
    get rails_health_check_path
    assert_response :success
  end

  test "the feed lists every rant, newest first, with no account" do
    get root_path
    assert_response :success
    assert_select "title", "Home · Rantly"
    assert_select ".masthead .wordmark__name", "rantly"
    assert_select ".masthead__tagline", "Let it all out."

    titles = css_select("[data-feed] .rant-card__title a").map { |a| a.text.strip }
    assert_equal Rant.feed("latest").map(&:title), titles
    assert_select "[data-feed] article.rant-card", SampleData.current.rants.size
  end

  test "a feed card links to the rant and its author, and counts its comments" do
    get root_path
    rant = Rant.find!("reply-all-is-not-a-personality")
    assert_select "article#rant-#{rant.id}" do
      assert_select "a[href=?]", rant_path(rant), text: rant.title
      assert_select "a[href=?] .byline__name", "/@deb_from_accounts", "Deborah Okafor"
      assert_select "a[href=?]", rant_path(rant, anchor: "comments"), text: /4 comments/
      assert_select ".tweets", "#{rant.tweets_worth} tweets' worth"
      assert_select "time[datetime=?]", rant.posted_at.in_time_zone.iso8601
    end
  end

  test "most discussed reorders the feed and marks its tab current" do
    get root_path(sort: "discussed")
    assert_response :success
    titles = css_select("[data-feed] .rant-card__title a").map { |a| a.text.strip }
    assert_equal Rant.feed("discussed").map(&:title), titles
    assert_select ".tabs a[aria-current=page]", "Most discussed"
  end

  test "an unknown sort shows the latest feed" do
    get root_path(sort: "<script>")
    assert_response :success
    assert_select ".tabs a[aria-current=page]", "Latest"
  end

  test "the demo composer is labelled as a demo and is not a form" do
    get root_path
    assert_select "[data-composer][data-min='140']" do
      assert_select ".badge--demo", "Demo · not saved"
      assert_select "label[for=composer-body]"
      assert_select "textarea#composer-body[data-composer-input]"
      assert_select "button[type=button][data-composer-submit][disabled]", "Rant"
    end
    assert_select "form", 0
  end

  test "the sidebar ranks the loudest ranters" do
    get root_path
    handles = css_select(".people .person__handle").map { |node| node.text[/@(\w+)/, 1] }
    assert_equal SampleData.current.loudest.map(&:handle), handles
  end

  test "a rant page shows the whole rant and its comments in order" do
    rant = Rant.find!("reply-all-is-not-a-personality")
    get rant_path(rant)
    assert_response :success
    assert_select "title", "#{rant.title} · Rantly"
    assert_select "h1#rant-title", rant.title
    assert_select ".rant__body p", rant.paragraphs.size
    assert_select ".rant__body p:last-child", rant.paragraphs.last
    assert_select "#comments h2", "4 comments"
    bodies = css_select(".comment__body").map { |node| node.text.strip }
    assert_equal rant.comments.map(&:body), bodies
    assert_select ".comment a.comment__name[href='/@nullpointer']", "Jun Park"
    assert_select ".more-list a[href=?]", rant_path("cancel-means-cancel")
  end

  test "a rant with no comments says so" do
    get rant_path("check-in-is-at-four")
    assert_response :success
    assert_select "#comments h2", "0 comments"
    assert_select "#comments .empty", /No comments yet/
  end

  test "an unknown rant is a 404" do
    get rant_path("no-such-rant")
    assert_response :not_found
    assert_match "The page you were looking for", response.body
  end

  test "the footer credits the 2014 original and says the data is fictional" do
    get root_path
    assert_select ".colophon a[href='https://github.com/amcritchie/rantly']", "amcritchie/rantly"
    assert_select ".colophon", /fictional sample data/
  end

  test "no page sets a cookie" do
    get root_path
    assert_nil response.headers["set-cookie"]
  end
end
