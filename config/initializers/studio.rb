# studio-engine, taken as a VIEW LIBRARY for the site footer, and nothing else.
#
# Rantly has no database, no accounts and no session (config/application.rb
# disables the session store), so it cannot take the engine's auth, admin pages,
# error logs or models: every one of them is ActiveRecord, and this app loads no
# ActiveRecord. What it takes is the footer helper (`studio_site_footer`, the
# engine's app/helpers/studio/site_footer_helper.rb), its partials and its
# scoped inline CSS. The engine's docs/SITE_FOOTER.md is the contract.
#
# The engine handles an app with no database itself (studio-engine >= 0.86,
# Studio.active_record?; its docs/SITE_FOOTER.md, "An app with no database"):
# it keeps its ActiveRecord-bound code out of eager loading, skips its check
# of the host's ::User (Rantly's is a fictional sample profile,
# app/models/user.rb, not an account) and makes
# `studio_engine:install:migrations` a no-op. The Gemfile floor is what holds
# that. The one thing left to this app is ROUTES: config/routes.rb does NOT
# call Studio.routes(self), so the engine draws nothing: no /login, /signup,
# /admin, /error_logs, /_studio/*.
#
# Taking more of the engine (sign-in, admin, error logs) means taking a
# database first; that is a separate decision, not this file's.
Studio.configure do |config|
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
                      [ "Most discussed", view.root_path(sort: "discussed") ] ] ],
        [ "About", [ [ "The 2014 original", "https://github.com/amcritchie/rantly" ],
                     [ "Made with McRitchie Studio", "https://mcritchie.studio/build" ] ] ],
        [ "Legal", [ [ "Privacy Policy", view.privacy_path ],
                     [ "Terms of Service", view.terms_path ] ] ]
      ],
      legal: [ [ "Privacy Policy", view.privacy_path ], [ "Terms of Service", view.terms_path ] ]
    }
  }
end
