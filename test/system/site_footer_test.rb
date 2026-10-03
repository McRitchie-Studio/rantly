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

  test "a footer link clears 4.5:1 against the footer band at the opacity the engine gives it" do
    # Each scheme is forced: headless Chrome otherwise follows the machine it runs on.
    scheme = ->(value) { page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "prefers-color-scheme", value: value } ]) }
    ratios = %w[light dark].to_h { |value| scheme.(value); visit root_path; [ value, page.evaluate_script(<<~JS) ] }
      (() => { const rgb = (c) => c.match(/[0-9.]+/g).slice(0, 3).map(Number);
               const a = document.querySelector("footer[data-site-footer] nav a.ftr-link"), s = getComputedStyle(a);
               const bg = rgb(getComputedStyle(a.closest("footer")).backgroundColor), o = Number(s.opacity);
               const lum = (c) => { const [r, g, b] = c.map((v) => { v /= 255; return v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4; });
                                    return 0.2126 * r + 0.7152 * g + 0.0722 * b; };
               const [hi, lo] = [ lum(rgb(s.color).map((v, i) => v * o + bg[i] * (1 - o))), lum(bg) ].sort((x, y) => y - x);
               return (hi + 0.05) / (lo + 0.05); })()
    JS
    ratios.each { |value, ratio| assert_operator ratio, :>=, 4.5, "footer links are #{ratio.round(2)}:1 on the #{value} footer band" }
  ensure
    scheme.("")
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
