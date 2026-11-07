require "test_helper"

# [unit] The layout's <title> names the site once.
class ApplicationHelperTest < ActionView::TestCase
  test "a page title gets the site name after it" do
    assert_equal "Terms of Service · Rantly", page_title("Terms of Service")
  end

  test "a title that already names the site keeps it once" do
    assert_equal "Page not found · Rantly", page_title("Page not found · Rantly")
  end

  test "no title is the home tagline" do
    assert_equal "Rantly · Let it all out", page_title(nil)
  end
end
