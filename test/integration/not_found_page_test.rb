require "test_helper"

# [integration] The friendly not-found page (task rantly-adopts-not-found-page;
# studio-engine docs/NOT_FOUND_PAGE.md): a lost visitor gets a 404 with Rantly's
# name and a button home, never a 200 or a redirect. That holds for an unknown
# address AND for a handle or rant that is not in data/sample.yml
# (SampleData::NotFound, mapped to 404 in config/application.rb), so one page
# serves both.
#
# config.exceptions_app is guarded on Studio::ExceptionsApp (engine 0.135.0), so
# these read whichever engine is locked: the engine page inside Rantly's layout,
# or the branded public/404.html (same words, same data-test hooks). Rantly has
# no database; the engine page renders without one. The test env hides
# exceptions, so each request runs with production's exception settings.
class NotFoundPageTest < ActionDispatch::IntegrationTest
  APP_NAME = "Rantly"
  ENGINE_PAGE = defined?(Studio::ExceptionsApp)

  def with_production_exceptions
    config = Rails.application.env_config
    saved = config.slice("action_dispatch.show_exceptions", "action_dispatch.show_detailed_exceptions")
    config["action_dispatch.show_exceptions"] = :all
    config["action_dispatch.show_detailed_exceptions"] = false
    yield
  ensure
    config.merge!(saved)
  end

  def get_lost(path, **options)
    with_production_exceptions { get path, **options }
  end

  # The page a lost visitor sees, on either engine: status 404, the friendly
  # words, Rantly's name and mark, and one button back to the root.
  def assert_friendly_page
    assert_response :not_found
    assert_nil response.location, "never a redirect"
    assert_equal "text/html", response.media_type
    assert_select "[data-test='not-found']", count: 1 do
      assert_select "h1", text: "This page isn’t here"
      assert_select "img[src='/icon.svg'][alt='#{APP_NAME}']", count: 1
      assert_select "a[data-test='not-found-home'][href='/']", text: "Back to #{APP_NAME}", count: 1
    end
    assert_select "title", "Page not found · #{APP_NAME}"
    if ENGINE_PAGE
      assert_select "[data-studio-not-found]", count: 1, message: "the engine's page"
      assert_select "header.masthead a.wordmark[href='/']", count: 1, message: "inside Rantly's layout"
      assert_select "[data-static-404]", count: 0
    else
      assert_select "body[data-static-404]", count: 1
    end
  end

  test "an unknown address answers 404 with the friendly page" do
    get_lost "/no-such-page"

    assert_friendly_page
  end

  test "a deeper unknown address gets the same page" do
    get_lost "/no/such/page/either"

    assert_friendly_page
  end

  test "a handle that is not in the sample file gets the same page" do
    get_lost "/@nobody_here"

    assert_friendly_page
  end

  test "a rant that is not in the sample file gets the same page" do
    get_lost "/rants/no-such-rant"

    assert_friendly_page
  end

  test "a page linked from Rantly offers a way back on the engine page" do
    skip "the static page has no back link" unless ENGINE_PAGE
    get_lost "/rants/no-such-rant", headers: { "Referer" => "http://www.example.com/discussed" }

    assert_friendly_page
    assert_select "a[data-test='not-found-back'][href='/discussed']", text: "Go back", count: 1
  end

  test "a JSON request answers 404 JSON, not the HTML page" do
    get_lost "/no-such-page", headers: { "Accept" => "application/json" }

    assert_response :not_found
    assert_equal "application/json", response.media_type
    assert_equal({ "status" => 404, "error" => "Not Found" }, response.parsed_body)
    assert_not_includes response.body, "<html"
  end

  test "a JSON request for a missing rant answers 404 JSON too" do
    get_lost "/rants/no-such-rant", headers: { "Accept" => "application/json" }

    assert_response :not_found
    assert_equal({ "status" => 404, "error" => "Not Found" }, response.parsed_body)
  end

  test "SampleData::NotFound is a 404 the exceptions app renders, not a controller rescue" do
    assert_equal :not_found, ActionDispatch::ExceptionWrapper.rescue_responses["SampleData::NotFound"]
    assert_not ApplicationController.rescue_handlers.any? { |klass, _| klass == "SampleData::NotFound" },
      "a rescue_from would answer before the exceptions app sees the error"
  end

  test "config/application.rb wires the engine's exceptions app once the engine has it" do
    if ENGINE_PAGE
      assert_kind_of Studio::ExceptionsApp, Rails.application.config.exceptions_app
    else
      assert_nil Rails.application.config.exceptions_app, "the guard keeps Rails' own on an older engine"
    end
  end

  test "the static last resort, public/404.html, carries the brand, the words and the home link" do
    page = Nokogiri::HTML(Rails.public_path.join("404.html").read)

    assert_equal "Page not found · #{APP_NAME}", page.at_css("title").text
    assert page.at_css("body[data-static-404] [data-test='not-found']")
    assert_equal "This page isn’t here", page.at_css("h1").text
    home = page.at_css("a[data-test='not-found-home']")
    assert_equal "/", home["href"]
    assert_equal "Back to #{APP_NAME}", home.text
    assert page.at_css("img[src='/icon.svg'][alt='#{APP_NAME}']"), "the brand mark"
    assert Rails.public_path.join("icon.svg").file?, "/icon.svg is in public/"
    assert_includes page.at_css("style").text, "#d63c1f", "Rantly's accent"
    assert_includes page.at_css("style").text, "prefers-color-scheme: dark"
    assert_empty page.css("script"), "the last resort runs nothing"
    assert_empty page.css("link[rel='stylesheet']"), "and loads nothing that could be missing"
  end
end
