# Rantly

A Twitter rival for people who need more room to rant: rantly.mcritchie.studio

Rantly is the social network with a **140-character minimum**. This is a 2026
rebuild of the 2014 original ([amcritchie/rantly](https://github.com/amcritchie/rantly),
Rails 4), built through McRitchie Studio's App Builder as a showcase. It keeps
the name, the tagline ("Let it all out") and the founding joke; none of the old
code was ported.

It is a Rails 8.1 app with **no database** and no accounts, so it runs on one
Heroku Eco dyno. Anyone can browse it without signing in. It takes
[studio-engine](https://github.com/McRitchie-Studio/studio-engine) for one
thing only, the shared site footer (see *Site footer* below).

## What it does

| Page | Path |
|------|------|
| The feed: every rant, newest first, or "Most discussed"; a demo composer; the loudest ranters | `/` (`/?sort=discussed`) |
| One rant, in full, with its comments and more from the author | `/rants/<id>` |
| A profile: bio, rants, who they follow and who follows them | `/@<handle>` |
| Privacy Policy · Terms of Service | `/privacy` · `/terms` |
| Health check | `/up` |

The composer on the feed is a **labelled demo**: it counts toward the
140-character floor and enables the button when you get there, but it is not a
form, sends nothing, and says so when pressed. Commenting is switched off.

## How it works

| Piece | Where |
|-------|-------|
| The sample world: 8 users, 14 rants, 27 comments, 22 follows (all fictional) | `data/sample.yml` |
| Loading it, the finders, and the house rules it must keep | `app/models/sample_data.rb` |
| The value objects the views use | `app/models/user.rb`, `rant.rb`, `comment.rb` (plain `Data` classes) |
| Pages | `app/controllers/rants_controller.rb`, `users_controller.rb`, `app/views/` |
| The demo composer | `app/javascript/composer.js` (plain ES module through importmap) |
| The look, light and dark | `app/assets/stylesheets/application.css` (plain CSS, no build step) |

`SampleData.current` reads the YAML once per process and freezes it, so no
request can change what the next one sees. An unknown handle or rant id raises
`SampleData::NotFound`, which the app answers with a logged 404.

To add a rant, a user, a follow or a comment, edit `data/sample.yml`. The house
rules are checked by `SampleDataTest`, which fails naming each broken one:

- a rant's body is at least 140 characters and its title at most 50
- every handle a rant, comment or follow names is a user in the file
- nobody follows themselves or the same person twice; ids and handles are unique
- a comment is posted after the rant it answers

## Site footer

Every page ends with studio-engine's site footer, under Rantly's own demo
colophon. The engine is used as a **view library**: `config/initializers/studio.rb`
declares the footer's facts (wordmark, logo, tagline, link columns, legal line)
and the layout calls `studio_site_footer`. The engine's own contract is its
`docs/SITE_FOOTER.md`.

Rantly takes none of the rest of the engine, because all of it (sign-in, admin
pages, error logs, theme settings) is ActiveRecord and Rantly has no database.
What that takes, each line commented where it lives:

| Where | What | Why |
|-------|------|-----|
| `config/routes.rb` | No `Studio.routes(self)` | The engine draws no routes: no `/login`, `/admin`, `/_studio/*` |
| `config/initializers/studio.rb` | The engine's `app/controllers`, `models`, `mailers`, `jobs` and `services` are kept out of eager loading | They subclass ActiveRecord, ActionMailer and ActiveJob and skip an auth callback Rantly does not have, so production's eager load would die on them. No route reaches them |
| `config/initializers/studio.rb` | `Studio.validate_user_contract = false` | Rantly's `User` is a fictional sample profile, not an account |
| `config/application.rb` | `require "active_support/core_ext/integer/time"` | The engine calls `Integer#minutes` while it loads, before Rails has loaded that extension in an app without ActiveRecord |
| `Rakefile` | `studio_engine:install:migrations` is a no-op | Rails' version dies with no ActiveRecord, and the hub's release sweep runs it after every engine publish and aborts on a failure |
| `app/assets/stylesheets/application.css` | `--color-*` tokens mapped to Rantly's palette | The footer reads the engine's theme tokens; without them it falls back to violet |

## Legal pages

`/privacy` and `/terms` are written from what the app does. Change a practice
below and the Privacy Policy changes in the same pull request;
`LegalControllerTest` fails when a page grows a cookie, a form or a request to
another origin.

| The policy says | Because |
|-----------------|---------|
| No accounts, no sign-in, no passwords | No auth anywhere; no database (`config/application.rb` loads no ActiveRecord) |
| Nothing typed in the rant box is sent or saved | `app/javascript/composer.js` makes no request; `app/views/shared/_composer.html.erb` is not a form |
| Commenting is off | No comment form; comments are sample data in `data/sample.yml` |
| No cookies, no browser storage | `config.session_store :disabled` (`config/application.rb`); no `localStorage` or cookie code in `app/` |
| No analytics or tracking scripts | `config/importmap.rb` pins only `application` and `composer` |
| Pages load nothing from other origins | Every asset is same-origin; the footer has no map (`config/initializers/studio.rb`) |
| Server logs hold IP, page, time and request details | Rails logs each request with the client IP at `info` (`config/environments/production.rb`); Heroku's router logs it too |
| Hosted by Heroku | *Deploy*, below |
| HTTPS only | `config.force_ssl = true` (`config/environments/production.rb`) |
| Operated by McRitchie Studio LLC, doing business as McRitchie Studio | The studio's showcase, made with McRitchie Studio's App Builder |

## Develop

```bash
bundle install
bin/rails server             # http://localhost:3000
bin/rails test               # unit + component + the production https probe
bin/rails test:system        # browsing and the demo composer in headless Chrome
bin/ci                       # everything CI runs
```

## Deploy

Heroku app `mcr-rantly` (company account, stack `heroku-26`, `heroku/ruby`
buildpack, no add-ons), one `web` process (`Procfile`; no release phase, since
there is nothing to migrate). There is no `config/credentials.yml.enc`;
production reads `SECRET_KEY_BASE` from the environment. The custom domain
`rantly.mcritchie.studio` is a CNAME to the Heroku DNS target, with Heroku ACM
for the certificate.

Production forces HTTPS: the Heroku router reports the visitor's scheme in
`X-Forwarded-Proto`, so `assume_ssl` stays off and plain `http://` gets a 301,
except `/up`, which answers on either scheme (`ProductionSslTest` boots
production to prove it). The session store is disabled, so no page sets a
cookie.

Branches follow the McRitchie three-rung ladder: feature PRs target `accepted`,
the release promotes `accepted` to `release`, and production ships `release` to
`main`. CI runs on every pull request and on pushes to all three.
