# Rantly

A Twitter rival for people who need more room to rant: rantly.mcritchie.studio

Rantly is the social network with a **140-character minimum**. This is a 2026
rebuild of the 2014 original ([amcritchie/rantly](https://github.com/amcritchie/rantly),
Rails 4), built through McRitchie Studio's App Builder as a showcase. It keeps
the name, the tagline ("Let it all out") and the founding joke; none of the old
code was ported.

It is a Rails 8.1 app with no accounts and **nothing stored**, so it runs on one
Heroku Eco dyno with no add-on. Its only database is a *token* (see *The token
database* below). Anyone can browse it without signing in. It takes
[studio-engine](https://github.com/McRitchie-Studio/studio-engine) for one
thing only: shared views, the site footer and the standard page header (see
*Site footer* and *Page header* below).

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
`SampleData::NotFound`. `config/application.rb` maps it to 404, so it gets the
same friendly not-found page as an unknown address (studio-engine's
`Studio::ExceptionsApp`, styled in `application.css`; `public/404.html` is the
branded last resort). Rails logs the error's message (`no rant <id>`) with the
request.

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

Rantly takes none of the rest of the engine. Sign-in, admin pages, error logs,
theme settings, magic links and the local-review hop all need the engine's
tables, and its migrations are written for Postgres, so the token database
cannot hold them. Because Rantly loads ActiveRecord, the engine would otherwise
take it for a full consumer, so Rantly keeps it footer-only itself:

| Where | What | Why |
|-------|------|-----|
| `config/routes.rb` | No `Studio.routes(self)` | The engine draws no routes: no `/login`, `/admin`, `/_studio/*` |
| `config/application.rb` | `rantly.engine_footer_only_eager_load` | Production eager loads only the engine's helpers; its controllers need a sign-in Rantly does not have |
| `lib/tasks/token_database.rake` | `studio_engine:install:migrations` is a no-op | The hub's release sweep runs it after every engine publish; the engine's migrations would not migrate on SQLite |
| `config/initializers/studio.rb` | `host_schema_check = false` | Boot does not demand the engine's `error_logs`, `theme_settings` and `image_caches` tables |
| `app/assets/stylesheets/application.css` | `--color-*` tokens mapped to Rantly's palette | The footer reads the engine's theme tokens; without them it falls back to violet |

## The token database

`config/database.yml` points every environment at a SQLite file under
`storage/` (git-ignored), and `db/schema.rb` is empty. It holds nothing. It
exists so the shared tooling finds the ActiveRecord app it expects: desk
bringup (`bin/agent-worktree up`) runs `bin/rails db:prepare`, and the hub's
pre-flight (`bin/fast-check`) boots the app at `RAILS_ENV=test` to prove the
desk has its own test database. `test/integration/token_database_test.rb` pins
both.

- **`url:`, not `database:`.** A desk exports `DATABASE_URL` at a Postgres
  database. Rails merges that over a `database:` entry but leaves an entry with
  its own `url:` alone, so each desk keeps its own SQLite files.
- **Production.** No add-on and no release phase. The file would sit on the
  dyno's ephemeral disk and be lost on each restart; that is acceptable only
  because nothing is stored. Today nothing even opens it.
- **Storing something real** means moving to Postgres first: hub
  `docs/agents/modules/token-database.md`, "Upgrade to Postgres".

## Page header

The feed (`/`, `/discussed`) and the legal pages open with studio-engine's
standard page header (`studio/_page_header`): the page's one h1 on the left,
the feed's two sorts as tabs on the right. It sticks under Rantly's sticky
masthead once the page scrolls. Rantly builds no Tailwind, so
`config/initializers/studio.rb` sets `config.page_header_self_styled = true`
(studio-engine >= 0.136.0) and the row brings its own scoped CSS and a small
module with no imports, once per page. The engine's own contract is its
`docs/PAGE_HEADER.md`. `/privacy` and `/terms` render inside the engine's
`studio/_legal_page` layout (the header, the "Last updated" line and a
readable column). A rant and a profile keep their h1 in their card and take
no page header.

| Where | What | Why |
|-------|------|-----|
| `application.css` `:root` | `--btn-primary-fg: var(--accent-ink)` | The current tab's text clears 4.5:1 on the accent in both schemes |
| `application.css` `:root` | `--color-primary-ink: #b83219` (light) | The link ink: every hover rule paints it (the global `a:hover`, crumbs, bylines, profile stats, the colophon, the legal column, the engine footer). `--accent` is 4.12:1 on light; this is 5.04:1 or better on every light surface |
| `application.css` `:root` | `--nav-h: 61px` | The masthead's height at every width; the stuck row pins under it before the module runs or with JavaScript off. Do not set `--nav-bottom` or `--pin-page-top` here: the module stops measuring when either is set |
| `application.css` `:root` | `--aside-gap: 23px` | The desktop sidebar sticks at `calc(var(--nav-h) + var(--aside-gap))`, 84px today, so a masthead change moves it too |
| `application.css` | `.ftr .ftr-link:hover { color: var(--color-primary-ink) }` | The engine footer's own hover paints `--color-primary` (3.91:1 on its light band) from an inline style after this sheet, so the pin is one class stronger |
| `application.css`, 560px query | `.page > .legal-page { padding-inline: 0 }` | On a phone the column's gutter would double `.page`'s |
| `application.css` | `.legal-page-body a:hover { color: var(--color-primary-ink) }` | The engine's `.legal-page-body a` ties the global `a:hover` on specificity; this keeps the link ink in either sheet order |

## Legal pages

`/privacy` and `/terms` are written from what the app does. Change a practice
below and the Privacy Policy changes in the same pull request;
`LegalControllerTest` fails when a page grows a cookie, a form or a request to
another origin.

| The policy says | Because |
|-----------------|---------|
| No accounts, no sign-in, no passwords | No auth anywhere; the token database is empty (`db/schema.rb`) and nothing writes to it |
| Nothing typed in the rant box is sent or saved | `app/javascript/composer.js` makes no request; `app/views/shared/_composer.html.erb` is not a form |
| Commenting is off | No comment form; comments are sample data in `data/sample.yml` |
| No cookies, no browser storage | `config.session_store :disabled` (`config/application.rb`); no `localStorage` or cookie code in `app/` |
| No analytics or tracking scripts | `config/importmap.rb` pins only `application` and `composer`; the one other script is studio-engine's same-origin page-header module (*Page header*), which makes no request |
| Pages load nothing from other origins | Every asset is same-origin; the footer has no map (`config/initializers/studio.rb`) |
| Server logs hold IP, page, time and request details | Rails logs each request with the client IP at `info` (`config/environments/production.rb`); Heroku's router logs it too |
| Hosted by Heroku | *Deploy*, below |
| HTTPS only | `config.force_ssl = true` (`config/environments/production.rb`) |
| Operated by McRitchie Studio LLC, doing business as McRitchie Studio | The studio's showcase, made with McRitchie Studio's App Builder |

## Develop

```bash
bundle install
bin/rails db:prepare         # the token database: empty SQLite files under storage/
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

### The static build (Cloudflare)

Rantly stores nothing (its token database is empty) and has only GET routes, so
it can be served as plain files.
`bin/static-build` precompiles the digested assets in production mode, renders
every page into `tmp/static/site` (`bin/rails static:build`, `lib/static_site.rb`)
and writes `tmp/static/site.manifest.json` beside it. It renders through the real
Rack app and crawls every internal link, so the bundle is what the dynamic app
serves; a link with a query string, or to a path that does not answer 200, stops
the build. Pages are written as `<path>/index.html`. Production still deploys to
Heroku today; once the hub's cutover procedure has run (`bin/static-downgrade
rantly --execute`, hub `docs/agents/modules/static-cloudflare.md`), the hub's
`static_cloudflare` release strategy uploads the directory to R2 and serves it at
`rantly.mcritchie.studio`.

`OUT=` and `HOST=` override the directory and the host the pages are built for.
The feed's "Most discussed" tab is `/discussed`, not `/?sort=discussed`, because
a static host ignores the query string.
