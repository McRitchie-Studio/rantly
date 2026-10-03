# studio-engine, taken as a VIEW LIBRARY for the site footer, and nothing else.
#
# Rantly has no database, no accounts and no session (config/application.rb
# disables the session store), so it cannot take the engine's auth, admin pages,
# error logs or models: every one of them is ActiveRecord, and this app loads no
# ActiveRecord. What it takes is the footer helper (`studio_site_footer`, the
# engine's app/helpers/studio/site_footer_helper.rb), its partials and its
# scoped inline CSS. The engine's docs/SITE_FOOTER.md is the contract.
#
# Three things the engine would otherwise force, and how each is declined:
#
# 1. ROUTES. config/routes.rb does NOT call Studio.routes(self), so the engine
#    draws nothing: no /login, /signup, /admin, /error_logs, /_studio/*.
#
# 2. EAGER LOADING. In production (and in CI, where config/environments/test.rb
#    turns eager_load on) Rails eager-loads the engine's app/ directories. Its
#    models subclass ApplicationRecord, its controllers skip
#    :require_authentication, its jobs subclass ActiveJob and its mailers
#    ActionMailer, none of which exist here, so the boot dies on the first one.
#    No route reaches any of them, so they are kept out of eager loading; they
#    stay lazily loadable and nothing ever asks for them. The engine's helpers
#    are left in, because the footer helper lives there.
#
# 3. THE USER CONTRACT. The engine checks the host's ::User against its
#    contract (find_by, admin?, display_name) after boot. Rantly's User is a
#    fictional sample profile (app/models/user.rb, a plain Data class read from
#    data/sample.yml), not an account, so the check is switched off.
#
# Taking more of the engine (sign-in, admin, error logs) means taking a
# database first; that is a separate decision, not this file's.
Studio.validate_user_contract = false

engine_app = Studio::Engine.root.join("app")
%w[controllers models mailers jobs services].each do |dir|
  path = engine_app.join(dir)
  Rails.autoloaders.main.do_not_eager_load(path.to_s) if path.directory?
end

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
