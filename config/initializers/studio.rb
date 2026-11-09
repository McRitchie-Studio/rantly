# studio-engine, taken as a VIEW LIBRARY for the site footer, and nothing else.
#
# Rantly has no accounts and no session (config/application.rb disables the
# session store), and its database is a TOKEN: an empty SQLite file
# (config/database.yml) that exists for the shared tooling and holds nothing.
# What Rantly takes from the engine is the footer helper
# (`studio_site_footer`, the engine's app/helpers/studio/site_footer_helper.rb),
# its partials and its scoped inline CSS, and the not-found page. The engine's
# docs/SITE_FOOTER.md is the contract.
#
# It takes none of the engine's database features (auth, admin pages, error
# logs, theme settings, magic links, the local-review hop). Their migrations
# are written for Postgres (`t.jsonb`, which SQLite does not have) and expect a
# `users` table, so the token database cannot hold them:
#   * config/routes.rb does NOT call Studio.routes(self), so the engine draws
#     nothing: no /login, /signup, /admin, /error_logs, /_studio/*.
#   * lib/tasks/token_database.rake makes `studio_engine:install:migrations`
#     a no-op, so the hub's release sweep copies no engine migration in.
#   * host_schema_check below is off, so boot does not demand the engine's
#     error_logs, theme_settings and image_caches tables.
# Rantly's ::User is a fictional sample profile (app/models/user.rb), not an
# ActiveRecord model, so the engine skips its user-contract check by itself.
#
# Taking more of the engine means moving to Postgres first: mcritchie-studio
# docs/agents/modules/token-database.md, "Upgrade to Postgres".
Studio.configure do |config|
  # The token database holds none of the engine's tables, by design (above).
  config.host_schema_check = false

  # The name and mark the engine's not-found page draws (Studio::ExceptionsApp,
  # config/application.rb; docs/NOT_FOUND_PAGE.md, "Where the words come from").
  # Rantly draws its own masthead, so the engine's navbar never reads these.
  config.app_name = "Rantly"
  config.navbar_brand = { logo: "/icon.svg", alt: "Rantly" }

  # The standard page header (studio/_page_header) and the legal page around it
  # (studio/_legal_page), styled by the engine itself: Rantly builds no Tailwind,
  # so the row brings its own scoped CSS and its small module, once per page
  # (studio-engine >= 0.136.0; its docs/PAGE_HEADER.md, "In a plain-CSS app").
  # They read the --color-* tokens app/assets/stylesheets/application.css maps.
  config.page_header_self_styled = true

  # The footer's facts (docs/SITE_FOOTER.md, "The facts"). Like Turf Monster's:
  # a wordmark and logo, a tagline, link columns and a legal line. No address,
  # no map, no phone, no booking schedule and no social profiles: Rantly shows
  # no handles of its own, and the map is the only thing in the footer that
  # would fetch from another origin.
  #
  # The contact address is the studio's shared inbox. Rantly showed no email
  # address before this footer, so this one is new on the site.
  #
  # logo is the PATH /icon.svg (public/), not an asset name: Propshaft's
  # image_tag raises on a logical name it cannot find in the load path.
  config.site_footer = ->(view) {
    {
      name: "Rantly",
      logo: "/icon.svg",
      tagline: "Let it all out. The social network with a 140-character minimum.",
      columns: [
        [ "Contact", [ [ "team@mcritchie.studio", "mailto:team@mcritchie.studio" ] ] ],
        [ "Rantly", [ [ "Latest rants", view.root_path ],
                      [ "Most discussed", view.discussed_path ] ] ],
        [ "About", [ [ "The 2014 original", "https://github.com/amcritchie/rantly" ],
                     [ "Made with McRitchie Studio", "https://mcritchie.studio/build" ] ] ],
        [ "Legal", [ [ "Privacy Policy", view.privacy_path ],
                     [ "Terms of Service", view.terms_path ] ] ]
      ],
      legal: [ [ "Privacy Policy", view.privacy_path ], [ "Terms of Service", view.terms_path ] ]
    }
  }
end
