require "application_system_test_case"

# Browser tier: every kind of link Rantly paints on hover keeps WCAG AA 4.5:1
# against what is behind it, light and dark, at desktop (1400px) and phone
# (390px) widths; and the sidebar's sticky offset follows the masthead token.
class HoverContrastSystemTest < ApplicationSystemTestCase
  WIDTHS = [ 1400, 390 ].freeze
  SCHEMES = %w[light dark].freeze

  # Each link kind: the page, the element to hover, and the element whose ink
  # the hover changes (the hovered element itself when nil).
  LINKS = {
    "a feed card's title" => [ "/", ".rant-card__title a", nil ],
    "a feed card's byline" => [ "/", ".byline__who", ".byline__name" ],
    "a crumb" => [ "/@rantly", ".crumb a", nil ],
    "a profile stat" => [ "/@rantly", ".profile__stats a", ".profile__stats a strong" ],
    "a colophon link" => [ "/", "footer.colophon a", nil ],
    "a site footer link" => [ "/", "footer[data-site-footer] a.ftr-link", nil ]
  }.freeze

  # The ink's contrast on the first opaque background behind it, with the ink
  # composited at its opacity (the engine footer has dimmed its links before).
  CONTRAST = <<~JS.freeze
    ((el) => { const rgb = (c) => c.match(/[0-9.]+/g).map(Number);
      let bgEl = el; while (bgEl && (rgb(getComputedStyle(bgEl).backgroundColor)[3] ?? 1) === 0) bgEl = bgEl.parentElement;
      const bg = rgb(getComputedStyle(bgEl || document.documentElement).backgroundColor).slice(0, 3);
      const s = getComputedStyle(el), o = Number(s.opacity);
      const ink = rgb(s.color).slice(0, 3).map((v, i) => v * o + bg[i] * (1 - o));
      const lum = (c) => { const [r, g, b] = c.map((v) => { v /= 255; return v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4; });
                           return 0.2126 * r + 0.7152 * g + 0.0722 * b; };
      const [hi, lo] = [ lum(ink), lum(bg) ].sort((x, y) => y - x);
      return (hi + 0.05) / (lo + 0.05); })
  JS

  test "every hovered link kind clears 4.5:1, light and dark, at 1400px and 390px" do
    failures = []
    SCHEMES.each do |scheme|
      emulate_scheme(scheme)
      WIDTHS.each do |width|
        emulate_width(width)
        LINKS.each do |kind, (path, target, ink)|
          visit path
          assert_equal width, page.evaluate_script("window.innerWidth"), "the emulated viewport did not take"
          # Transitions off: the engine footer fades a link's colour over 150ms.
          page.execute_script("document.head.insertAdjacentHTML('beforeend', '<style>*{transition:none!important}</style>')")
          link = find(target, match: :first)
          rest = page.evaluate_script("getComputedStyle(document.querySelector(#{(ink || target).to_json})).color")
          link.hover
          assert page.evaluate_script("document.querySelector(#{target.to_json}).matches(':hover')"), "#{kind}: the hover did not take"
          hovered = page.evaluate_script("getComputedStyle(document.querySelector(#{(ink || target).to_json})).color")
          refute_equal rest, hovered, "#{kind} at #{width}px #{scheme}: the hover changed no colour, so this measures nothing"
          ratio = page.evaluate_script("(#{CONTRAST})(document.querySelector(#{(ink || target).to_json}))")
          failures << "#{kind} on #{path} at #{width}px #{scheme}: #{ratio.round(2)}:1" if ratio < 4.5
        end
      end
    end
    assert_empty failures, "hovered links under 4.5:1:\n#{failures.join("\n")}"
  ensure
    reset_emulation
  end

  # The masthead sticks at 0; the sidebar sticks the masthead's height (--nav-h)
  # plus a 23px gap below it, 84px today. A change to --nav-h must move it too.
  test "the sidebar pins 23px under the masthead at desktop, and follows --nav-h" do
    emulate_width(1400)
    # The feed: its main column is thousands of pixels taller than the sidebar,
    # so the sidebar has room to stay stuck after a 1500px scroll.
    visit "/"
    assert_equal 1400, page.evaluate_script("window.innerWidth"), "the emulated viewport did not take"
    page.execute_script("window.scrollTo(0, 1500)")
    assert_equal 1500, page.evaluate_script("Math.round(window.scrollY)"), "the feed did not scroll 1500px"
    masthead, aside = page.evaluate_script(<<~JS)
      [document.querySelector('header.masthead').getBoundingClientRect().bottom,
       document.querySelector('.layout__aside').getBoundingClientRect().top]
    JS
    assert_in_delta 61, masthead, 0.5, "the masthead is no longer 61px tall"
    assert_in_delta 84, aside, 0.5, "the stuck sidebar's top moved from 84px"

    page.execute_script("document.documentElement.style.setProperty('--nav-h', '100px')")
    moved = page.evaluate_script("document.querySelector('.layout__aside').getBoundingClientRect().top")
    assert_in_delta 123, moved, 0.5, "with --nav-h at 100px the sidebar should stick at 123px, not #{moved}px"
  ensure
    reset_emulation
  end

  private

  def cdp(name, **params) = page.driver.browser.execute_cdp(name, **params)

  # Headless Chrome will not size its window below 500px; emulate instead.
  def emulate_width(width)
    cdp("Emulation.setDeviceMetricsOverride", width: width, height: 900, deviceScaleFactor: 1, mobile: width < 768)
  end

  # Reduced motion too, so Rantly's own colour transitions stand down.
  def emulate_scheme(value)
    cdp("Emulation.setEmulatedMedia", features: [ { name: "prefers-color-scheme", value: value },
                                                  { name: "prefers-reduced-motion", value: value.empty? ? "" : "reduce" } ])
  end

  def reset_emulation
    cdp("Emulation.clearDeviceMetricsOverride")
    emulate_scheme("")
  end
end
