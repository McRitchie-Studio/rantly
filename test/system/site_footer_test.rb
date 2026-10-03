require "application_system_test_case"

# Browser tier: the engine's site footer in headless Chrome, at the five widths
# the engine's own layout spec holds (320, 390, 768, 1024, 1280), on Rantly's
# own palette, and the walk from the footer to the legal pages.
class SiteFooterSystemTest < ApplicationSystemTestCase
  WIDTHS = [ 320, 390, 768, 1024, 1280 ].freeze
  PAGES = [ "/", "/rants/we-said-140-and-we-meant-it", "/@rantly", "/privacy", "/terms" ].freeze

  test "the footer fits every width without a sideways scroll, and keeps the email whole" do
    WIDTHS.each do |width|
      # Headless Chrome will not size its window below 500px; emulate instead.
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 900, deviceScaleFactor: 1, mobile: width < 768)
      PAGES.each do |path|
        visit path
        assert_selector "footer[data-site-footer]"
        assert_equal width, page.evaluate_script("window.innerWidth"), "the emulated viewport did not take"
        overflow = page.evaluate_script("document.documentElement.scrollWidth") - width
        assert_operator overflow, :<=, 0, "#{path} at #{width}px is #{overflow}px too wide"
        email_lines = page.evaluate_script(<<~JS)
          (() => { const a = document.querySelector('footer[data-site-footer] a[href^="mailto:"]');
                   const r = a.getClientRects(); return r.length; })()
        JS
        assert_equal 1, email_lines, "#{path} at #{width}px broke the email address across lines"
      end
    end
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  test "the footer wears Rantly's accent, not the engine's violet fallback" do
    visit root_path
    # Whichever scheme the browser is in, the wordmark is --accent's colour:
    # rgb(214, 60, 31) light, rgb(255, 106, 77) dark; the fallback is violet.
    wordmark = page.evaluate_script("getComputedStyle(document.querySelector('.ftr-wordmark-accent')).color")
    accent = page.evaluate_script(<<~JS)
      (() => { const probe = document.createElement('span'); probe.style.color = 'var(--accent)';
               document.body.append(probe); const c = getComputedStyle(probe).color; probe.remove(); return c; })()
    JS
    assert_includes [ "rgb(214, 60, 31)", "rgb(255, 106, 77)" ], wordmark
    assert_equal accent, wordmark
  end

  test "the footer's legal links reach both pages" do
    visit root_path
    within "footer[data-site-footer] nav[aria-label=Legal]" do
      click_on "Privacy Policy"
    end
    assert_selector "h1", text: "Privacy Policy"
    within "footer[data-site-footer] nav[aria-label=Legal]" do
      click_on "Terms of Service"
    end
    assert_selector "h1", text: "Terms of Service"
  end
end
