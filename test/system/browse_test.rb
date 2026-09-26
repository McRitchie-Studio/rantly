require "application_system_test_case"

# Browser tier: a visitor with no account reads the feed, opens a rant, meets
# its author, and tries the demo composer, in headless Chrome.
class BrowseTest < ApplicationSystemTestCase
  test "feed to rant to profile and back" do
    visit root_path
    assert_selector "h2.rant-card__title", count: SampleData.current.rants.size

    within "#rant-boarding-group-nine" do
      click_on "There is no such thing as boarding group nine"
    end
    assert_selector "h1", text: "There is no such thing as boarding group nine"
    assert_text "After group eight."
    assert_selector "#comments h2", text: "2 comments"

    within ".rant" do
      click_on "Marcus Bell"
    end
    assert_selector "h1", text: "Marcus Bell"
    within "#following" do
      assert_link "Eleanor Voss"
      click_on "Eleanor Voss"
    end
    assert_selector "h1", text: "Eleanor Voss"

    click_on "Back to the feed"
    assert_selector ".tabs a[aria-current=page]", text: "Latest"
  end

  test "the demo composer counts toward 140 and never posts" do
    visit root_path
    composer = find("[data-composer]")
    button = composer.find_button("Rant", disabled: :all)
    assert button.disabled?
    assert_selector "[data-composer-count]", text: "140 characters to go"

    fill_in "Your rant", with: "Short."
    assert_selector "[data-composer-count]", text: "134 characters to go"
    assert button.disabled?

    fill_in "Your rant", with: "a" * 139
    assert_selector "[data-composer-count]", text: "1 character to go"

    fill_in "Your rant", with: "a" * 140
    assert_selector "[data-composer-count].is-ready", text: "140 characters. That's a rant."
    refute button.disabled?

    feed_before = all("[data-feed] article").size
    url_before = current_url
    button.click
    assert_selector "[data-composer-note].is-shouting", text: "Demo only: your rant was not posted or saved."
    assert_equal url_before, current_url
    assert_equal feed_before, all("[data-feed] article").size
  end

  test "Most discussed puts the busiest rant on top" do
    visit root_path
    click_on "Most discussed"
    assert_selector ".tabs a[aria-current=page]", text: "Most discussed"
    assert_equal "Reply-all is not a personality", first("h2.rant-card__title").text
  end

  test "a phone-width screen never scrolls sideways" do
    # Headless Chrome will not size its window below 500px, so emulate the
    # phone's viewport through DevTools instead of resizing the window.
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 390, height: 844, deviceScaleFactor: 2, mobile: true)
    [ root_path, rant_path("boarding-group-nine"), user_path("deb_from_accounts") ].each do |path|
      visit path
      overflow = page.evaluate_script("document.documentElement.scrollWidth") - 390
      assert_operator overflow, :<=, 0, "#{path} is #{overflow}px wider than a 390px phone"
      assert_equal 390, page.evaluate_script("window.innerWidth"), "the emulated viewport did not take"
    end
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end
end
