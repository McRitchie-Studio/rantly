# Rantly

A Twitter rival for people who need more room to rant: rantly.mcritchie.studio

Rantly is the social network with a **140-character minimum**. This is a 2026
rebuild of the 2014 original ([amcritchie/rantly](https://github.com/amcritchie/rantly),
Rails 4), built through McRitchie Studio's App Builder as a showcase. It keeps
the name, the tagline ("Let it all out") and the founding joke; none of the old
code was ported.

It is a Rails 8.1 app with **no database**, no accounts and no studio-engine, so
it runs on one Heroku Eco dyno. Anyone can browse it without signing in.

## What it does

| Page | Path |
|------|------|
| The feed: every rant, newest first, or "Most discussed"; a demo composer; the loudest ranters | `/` (`/?sort=discussed`) |
| One rant, in full, with its comments and more from the author | `/rants/<id>` |
| A profile: bio, rants, who they follow and who follows them | `/@<handle>` |
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
