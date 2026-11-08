require "application_system_test_case"

# Browser tier: studio-engine's self-styled page header on Rantly, at desktop
# (1400px) and phone (390px) widths, in light and dark. The row sticks under
# Rantly's own sticky masthead once the page scrolls, the page never scrolls
# sideways, and the current tab's text clears 4.5:1 on its fill.
class PageHeaderSystemTest < ApplicationSystemTestCase
  WIDTHS = [ 1400, 390 ].freeze
  SCHEMES = %w[light dark].freeze
  PAGES = { "/" => "Rants", "/privacy" => "Privacy Policy" }.freeze

  CONTRAST = <<~JS.freeze
    ((el, bgEl) => { bgEl = bgEl || el; const rgb = (c) => c.match(/[0-9.]+/g).slice(0, 3).map(Number);
      const lum = (c) => { const [r, g, b] = c.map((v) => { v /= 255; return v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4; });
                           return 0.2126 * r + 0.7152 * g + 0.0722 * b; };
      const [hi, lo] = [ lum(rgb(getComputedStyle(el).color)), lum(rgb(getComputedStyle(bgEl).backgroundColor)) ].sort((x, y) => y - x);
      return (hi + 0.05) / (lo + 0.05); })
  JS

  test "the header sticks under the masthead at 1400px and 390px, light and dark" do
    SCHEMES.each do |scheme|
      emulate_scheme(scheme)
      WIDTHS.each do |width|
        emulate_width(width)
        PAGES.each do |path, title|
          visit path
          where = "#{path} at #{width}px #{scheme}"
          assert_selector ".page-header h1", text: title
          assert_equal width, page.evaluate_script("window.innerWidth"), "the emulated viewport did not take"
          assert_equal 1, page.evaluate_script("document.querySelectorAll('h1').length"), "#{where}: one h1"
          assert_operator page.evaluate_script("document.documentElement.scrollWidth"), :<=, width, "#{where} scrolls sideways"

          # The row's styles came from the engine's sheet, in Rantly's tokens.
          size = page.evaluate_script("parseFloat(getComputedStyle(document.querySelector('.page-header-title')).fontSize)")
          assert_equal(width >= 640 ? 30.0 : 24.0, size, "#{where}: the title is not self-styled")

          assert_operator page.evaluate_script("document.documentElement.scrollHeight - window.innerHeight"), :>=, 1500, "#{where} is too short to scroll 1500px"
          page.execute_script("window.scrollTo(0, 1500)")
          assert_selector ".page-header[data-stuck]", wait: 2
          masthead, row = page.evaluate_script(<<~JS)
            [document.querySelector('header.masthead').getBoundingClientRect().bottom,
             document.querySelector('.page-header').getBoundingClientRect().top]
          JS
          assert_in_delta masthead, row, 1, "#{where}: the stuck row is not pinned under the masthead"
          bar = page.evaluate_script("getComputedStyle(document.querySelector('.page-header')).backgroundColor")
          refute_equal "rgba(0, 0, 0, 0)", bar, "#{where}: the stuck row has no bar"
        end
      end
    end
  ensure
    reset_emulation
  end

  test "the current tab and the legal page's links clear 4.5:1, light and dark" do
    SCHEMES.each do |scheme|
      emulate_scheme(scheme)
      visit root_path
      # Where the browser anchors the gliding pill, the pill carries the fill and the
      # current tab is transparent over it.
      tab = page.evaluate_script(<<~JS)
        (() => { const tab = document.querySelector('.page-header-tab[aria-current]');
                 const glide = document.querySelector('.page-header-glide');
                 return (#{CONTRAST})(tab, getComputedStyle(glide).display === 'none' ? tab : glide); })()
      JS
      assert_operator tab, :>=, 4.5, "the current tab is #{tab.round(2)}:1 in #{scheme}"
      visit privacy_path
      link = page.evaluate_script("(#{CONTRAST})(document.querySelector('.legal-page-body a'), document.body)")
      assert_operator link, :>=, 4.5, "a legal page link is #{link.round(2)}:1 on the page in #{scheme}"
    end
  ensure
    reset_emulation
  end

  test "on a phone the legal column does not double the page's gutter" do
    emulate_width(390)
    visit privacy_path
    left = page.evaluate_script("document.querySelector('.legal-page-body').getBoundingClientRect().left")
    assert_in_delta 16, left, 1, "the legal text starts #{left}px in; .page's 16px gutter alone should hold it"
  ensure
    reset_emulation
  end

  private

  def cdp(name, **params) = page.driver.browser.execute_cdp(name, **params)

  # Headless Chrome will not size its window below 500px; emulate instead.
  def emulate_width(width)
    cdp("Emulation.setDeviceMetricsOverride", width: width, height: 900, deviceScaleFactor: 1, mobile: width < 768)
  end

  # Reduced motion too: the engine then drops the row's 150ms fade, so the stuck
  # bar's colour reads settled the moment data-stuck lands.
  def emulate_scheme(value)
    cdp("Emulation.setEmulatedMedia", features: [ { name: "prefers-color-scheme", value: value },
                                                  { name: "prefers-reduced-motion", value: value.empty? ? "" : "reduce" } ])
  end

  def reset_emulation
    cdp("Emulation.clearDeviceMetricsOverride")
    emulate_scheme("")
  end
end
