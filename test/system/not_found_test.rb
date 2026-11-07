require "application_system_test_case"

# Browser tier: a visitor who follows a dead link to a rant lands on the
# friendly not-found page (task rantly-adopts-not-found-page) and gets home in
# one click. The test env hides exceptions, so the visit runs with production's
# exception settings; the server thread reads the same env_config.
class NotFoundTest < ApplicationSystemTestCase
  def with_production_exceptions
    config = Rails.application.env_config
    saved = config.slice("action_dispatch.show_exceptions", "action_dispatch.show_detailed_exceptions")
    config["action_dispatch.show_exceptions"] = :all
    config["action_dispatch.show_detailed_exceptions"] = false
    yield
  ensure
    config.merge!(saved)
  end

  test "a missing rant shows the not-found page and its button goes home" do
    with_production_exceptions do
      visit "/rants/no-such-rant"

      within "[data-test='not-found']" do
        assert_selector "h1", text: "This page isn’t here"
        click_on "Back to Rantly"
      end
    end

    assert_current_path root_path
    assert_selector "h2.rant-card__title", count: SampleData.current.rants.size
  end
end
