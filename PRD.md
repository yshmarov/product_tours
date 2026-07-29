# PRD: product_tours

> Status: draft, revised 2026-07-30. Scope locked after review against the
> shipped gems (`livechat`, `testimonials`, `ideasbugs`, `i18n_proofreading`).
> Key decision: **no DOM-anchored tooltip tours** (the intro.js/Driver.js
> model). Guidance is delivered as self-contained modals, inline cards, and
> checklists that render their own UI and never attach to the host's DOM —
> the same shape that made the other four gems reliable.

## Summary

`product_tours` is a Rails engine for self-hosted product adoption: in-app
onboarding guides, video walkthroughs, multi-step modal guides, and (from v0.2)
checklists — all managed inside the host app and stored in the host database.

It aims to be the Rails-native alternative to Appcues, Userflow, Chameleon, and
Pendo for teams that want in-app guidance without a third-party script, an
external user database, MAU pricing, or a separate product-adoption platform.

```ruby
gem "product_tours"
```

```erb
<%# app/views/layouts/application.html.erb, before </body> %>
<%= product_tours_tag %>

<%# Any page where the app knows the right context %>
<%= product_tour_button(:billing_setup) %>
<%= product_tour_embed(:onboarding_video) %>
```

Product promise:

> Product tours for Rails. Build in-app onboarding, feature guides, and
> checklists from your own app. Your UI, your database, no third-party widget.

## Why no DOM-anchored tours

Appcues/Userflow/Chameleon/Pendo and OSS libraries like Driver.js and Intro.js
attach a popover to a live host DOM element and reposition it across scrolling,
sticky headers, transforms, breakpoints, and mobile. That positioning engine is
the hard, high-maintenance, high-visibility-when-broken core of the category —
and it is the one thing that made those tools not gem-sized.

`product_tours` deliberately skips it. Guidance renders as **centered,
self-contained UI** (a modal, an inline card, a checklist), never pinned to a
host element. This keeps the gem the same "renders its own widget" shape as
`livechat`/`testimonials`/`ideasbugs`, keeps it dependency-free, and removes the
failure mode where a mispositioned popover looks obviously broken. Multi-step
guidance is a paginated modal ("1 of 3", Back/Next), not a DOM walkthrough.

## Market Scan

Hosted product-adoption tools converge on a broad, expensive surface:

- Appcues — flows, checklists, embeds, segmentation, reporting; MAU/published-
  experience pricing. [Experiences](https://www.appcues.com/experiences),
  [Pricing](https://www.appcues.com/pricing).
- Userflow — tours, checklists, banners, launchers, targeting, analytics, AI;
  from ~$500/mo at 1K MAUs. [Site](https://www.userflow.com/),
  [Pricing](https://www.userflow.com/pricing).
- Chameleon — tours, tooltips, embeddables, launchers, targeting, localization;
  Pro from ~$750/mo. [Tours](https://www.chameleon.io/tours),
  [Plans](https://www.chameleon.io/plans).
- Pendo — an always-available in-app guide center of guides, checklists, and
  announcements. [Docs](https://support.pendo.io/hc/en-us/articles/360031866712-Overview-of-the-Resource-Center).

Conclusion: SaaS competitors bundle a lot; this gem should not. The Rails
opportunity is the sharper 80% — modal/video guides, multi-step modals,
checklists, success-event prompts, simple targeting, and useful progress/event
data — delivered as native Rails helpers over host-owned data. Adjacent surface
belongs in sibling gems or host code until real demand proves otherwise.

## Positioning

**Self-hosted product adoption for Rails.** Developers place stable hooks
(`product_tours_tag`, helper buttons, success-event calls). Product/support/admin
users manage content from a mounted dashboard. End-user behavior is tracked in
the same database as the product.

Intentionally different from generic SaaS:

- The host app already knows the user, account, plan, role, flags, and lifecycle.
  Resolve them with request lambdas — don't sync a shadow customer database.
- The host app already has auth, tenancy, mailers, jobs, CSP, and I18n. Fit
  those systems instead of replacing them.
- Sibling gems own adjacent jobs. `testimonials`, `ideasbugs`, and `livechat`
  own their workflows; `product_tours` owns guidance and activation only.

Tagline:

> `product_tours` — product tours, onboarding checklists, and in-app guidance
> for Rails. Self-hosted, no third-party script, no MAU tax.

## Goals

- Install in under 5 minutes on a fresh Rails app.
- Rails 7.1+, Ruby 3.2+, mountable engine, isolated namespace `ProductTours`.
- Store guides, steps, progress, and events in host-app tables.
- Place guides by stable developer-facing keys.
- Let admins edit content, ordering, status, CTA, and media without a deploy.
- Let the host invoke guides after success events, not only button clicks.
- Support signed-in and anonymous visitors.
- Support multi-tenant apps via an opaque tenant key.
- Support eligibility via host-provided segments, not user-data sync.
- Work with plain Rails views, Turbo Drive, and strict nonce-based CSP.
- No Tailwind, Stimulus, importmap, node, npm, CDN, or asset-pipeline assumptions.
- Enough analytics to answer: who saw this, who dismissed it, who completed it.

## Non-Goals

Absolute non-goals for v1:

- **No DOM-anchored tooltip tours** (no popover pinned to a host element, no
  positioning engine, no `data-*-anchor` markers).
- No external hosted service; no third-party tracking script.
- No syncing users/accounts into a vendor database.
- No visual builder, AI authoring, or chatbot.
- No mobile SDKs.
- No testimonial or feedback collection (sibling gems own those).
- No media creation/hosting; the gem accepts video links (and later, uploads).
- No enterprise workflow suite: roles, approvals, SAML, experiments, governance.

Deferred until real demand:

- Advanced analytics charts.
- Active Storage uploads for media (schema is upload-ready; see below).
- `auto` and `completion` trigger modes.
- Deep integrations (Segment, Amplitude, Mixpanel, Slack, …). Hooks and recipes
  come first.

## Product Principles

- **Rails-native beats no-code.** The win is native placement, auth, tenancy,
  I18n, and persistence.
- **Self-contained UI.** The widget renders its own modals/cards and never
  touches the host DOM.
- **Developer-placed, admin-managed.** Code defines where guidance may appear;
  admins manage content and publishing.
- **Intent beats interruption.** Explicit clicks, success moments, and
  checklists over surprise auto-starts.
- **Calm product scope.** Basecamp-style: the small thing that solves the real
  Rails problem. Fewer settings, documented escape hatches, no platform sprawl.
- **One guide, one outcome.** A guide drives a single activation milestone.
- **Self-hosted by default.** Content and events stay in the host database.
- **Small frontend, strong backend.** Plain JS for playback/modals; Active
  Record for content, eligibility, and analytics.
- **Strict CSP is table stakes.** Same-origin scripts, nonce support, no inline
  handlers.
- **Screenshots sell the gem.** The README must show a polished modal, video
  guide, multi-step modal, checklist, and dashboard before wide announcement.

## Boundaries With Sibling Gems

- `testimonials` — testimonials, video reviews, consent, public collection.
- `ideasbugs` — private feedback, bugs, feature requests, triage.
- `livechat` — user-to-team support messaging.
- `i18n_proofreading` — translation review.
- `product_tours` — product guidance: "show this user how to complete this
  workflow now."

Integration through hooks and docs, not duplicated surface: a completed guide
may trigger `testimonial_prompt!` in host code, but `product_tours` ships no
review prompt of its own.

## Reference Gem Patterns To Reuse

Follow the shipped-gem house architecture:

- `isolate_namespace ProductTours`; `ProductTours::Configuration` PORO with safe
  defaults; `ProductTours.configure { |config| ... }`.
- Request-dependent lambdas receive the raw request.
- Dashboard access defaults to development only; public/user endpoints are
  independently gated by `enabled`.
- Loose host references: `author_id`, `visitor_token`, `tenant` are strings, not
  foreign keys.
- Optional model concern via `ActiveSupport.on_load(:active_record)`; widget
  helper via `:action_view`; controller helper via `:action_controller`.
- Widget JS and dashboard JS live in `lib/product_tours/*.js`, served same-origin
  by the engine with content fingerprints.
- Helpers emit a `type="application/json"` config script plus a same-origin
  `defer` script — the Turbo/CSP-safe pattern from the other gems.
- Runtime dependency: Rails only, unless overwhelmingly justified.
- Minitest, not RSpec; `test/dummy` app with fixed-nonce CSP tests.
- CI matrix: Rails 7.1/7.2/8.0/8.1 × Ruby 3.2/3.3/3.4.
- 26 locale files with a parity test.
- README: badges, one-line positioning, screenshot/GIF, install, "What you get",
  "Why self-host", flow screenshots, config table, multi-tenancy, Turbo/CSP,
  tests. Keep-a-Changelog `CHANGELOG.md`. Trusted-publishing release on `v*`.
- Mobile: full-screen modal at ≤480px with the `visualViewport` keyboard fix,
  16px inputs, safe-area padding, contained overscroll (the family convention).

## Personas

1. **End user** — signed-in or anonymous, learning a workflow in the host app.
2. **Customer admin** — tenant-side admin completing setup / discovering features.
3. **Product/support/admin** — manages guide content, watches counts, retires
   stale guides.
4. **Host developer** — installs the gem, places triggers, wires auth, tenant,
   segments, and completion events.

## Core Product Surface

### 1. Guide Library

A guide is the base content unit, presented as a modal, inline embed, or (v0.2)
checklist item. v0.1 supports:

- single modal guides (title/body/CTA)
- video guides (modal or inline)
- **multi-step modal guides** — a centered, paginated modal ("1 of N",
  Back/Next), attached to nothing
- inline embed guides
- CTA links
- `product_tour_prompt!` / `product_tour_complete!` from controller code
- `shown` / `started` / `viewed` / `step_viewed` / `dismissed` / `completed` /
  `cta_clicked` events
- tenant scoping
- eligibility by segment

v0.2: onboarding checklists; show-once / show-until-completed behavior.

An always-available in-app `Guides` launcher is explicitly parked (revisit at
v0.4, after the core loop is polished).

### 2. Multi-Step Modal Guides

A guide with more than one step renders as a single centered modal that
paginates through its steps — **not** a DOM walkthrough.

Behavior:

- Each step supports title, body, optional video/media URL, primary CTA, and a
  secondary "Skip/Close".
- Progress text ("Step 2 of 3") for multi-step guides; Back/Next controls.
- Keyboard: Escape dismisses; Enter/Space activate controls; focus is trapped
  while the modal is open.
- Mobile: full-screen modal (family convention), keyboard-safe via
  `visualViewport`.
- A guide with no renderable steps does not open.
- Playback stops when the modal closes (the player node is removed).

All plain JS in the gem; no third-party overlay library, because there is no
positioning to solve.

### 3. Video Guides

Video is one guide format, not the whole product. v0.1 providers:

- YouTube, Vimeo, Loom, Tella, Voomly, and direct MP4/WebM URLs.

Resolver (offline, security-critical — the last line of defense):

- A dedicated resolver object parses URLs and derives embeddable player URLs.
- Accept only HTTPS URLs from known provider hosts. Unsupported hosts, non-video
  paths, invalid URLs, lookalike hosts, and non-HTTPS schemes resolve to no
  embed — never an arbitrary iframe.
- YouTube normalizes watch/shorts/live/embed/`youtu.be` to
  `youtube-nocookie.com/embed/<id>?rel=0&modestbranding=1`.
- Vimeo preserves unlisted privacy hashes.
- Voomly accepts iframe embed URLs and share/embed URLs from Voomly's video
  drive; v0.1 treats it as an iframe player and records `viewed` (player-API
  completion can come later).
- Direct media URLs use a native `<video>` player.
- Record `completed` only where completion can be detected reliably; otherwise
  fall back to `viewed`/`dismissed`.
- Never require Active Storage in v0.1; never record video in the browser.

oEmbed (dashboard-only, admin convenience — never on the end-user render path):

- Provider oEmbed fetchers for YouTube and Vimeo first (keyless public
  endpoints). Wistia later only if the resolver is already clean.
- On save/preview of a URL, offer "Fetch video data" to prefill **blank** fields
  (guide title, provider title, thumbnail URL, provider, provider id, embed URL).
  Never silently overwrite admin-edited fields; an explicit "Refresh video data"
  may replace generated provider metadata after confirmation.
- Persist practical normalized fields; store the raw payload in
  `metadata["oembed"]` only when useful.
- Network failure must never block saving a guide.

Upload-ready media design (columns exist from the first migration so uploads are
additive later):

- `video_url` (original pasted URL), `embed_url` (normalized player URL),
  `thumbnail_url`, `captions_url`, `provider`, `provider_id`, `provider_title`,
  `media_kind` (`url` in v0.1; `upload` later).
- When uploads arrive, attach files separately but expose them through the same
  player-facing methods; an upload wins over a URL at render time, URL remains as
  fallback metadata. Purge removed uploads after commit, not inside the save
  transaction. The gem never generates thumbnails, transcodes, or edits captions.

### 4. Checklists (v0.2)

- `product_tour_checklist(:onboarding)` renders a self-styled checklist.
- Ordered items; each launches a guide, navigates to a URL, or completes from a
  host completion event.
- Progress stored per visitor/user/tenant.
- Hides when all required items complete, unless configured to remain available.

The v0.1 schema must not block this.

### 5. Server-Side Prompts And Completion

The host app knows success moments — copy the `testimonials` pattern:

```ruby
class BillingController < ApplicationController
  def update
    # ...
    product_tour_complete!(:billing_setup)
    product_tour_prompt!(:invite_team)
    redirect_to billing_path
  end
end
```

- `product_tour_prompt!(key)` stores a flash-like signal for the next HTML
  render (a v0.1 requirement — guides must be invokable from success events like
  "invoice created", "team invited", "billing connected").
- Auto-prompting respects recurrence; explicit clicks bypass recurrence.
- `product_tour_complete!(key)` records completion for the current
  user/visitor/tenant and creates a `completed` event.

### 6. Guides Launcher (parked, v0.4)

An optional always-available launcher listing eligible guides/checklists.
Explicit parking-lot idea — no schema, routes, helpers, or config until the core
guide/checklist product is useful in a real app.

## Installation

```bash
bundle add product_tours
bin/rails generate product_tours:install
bin/rails db:migrate
```

The installer creates an initializer, a migration, the engine mount route, and
post-install instructions. Default mount path `/product_tours`.

```erb
<%= product_tours_tag %>
```

Post-install output: run `rails db:migrate`; add `<%= product_tours_tag %>`
before `</body>`; manage guides at `/product_tours`; dashboard is development-
only until `config.authorize_admin` is set.

## Configuration

```ruby
ProductTours.configure do |config|
  config.enabled = ->(_request) { true }
  config.authorize_admin = ->(_request) { Rails.env.development? }
  config.current_user = ->(_request) {}
  config.tenant = ->(_request) {}
  config.author_label = ->(user) { user.try(:name).presence || user.try(:email).presence || user&.to_s }
  config.visitor_label = ->(user) { user.try(:name).presence || user.try(:email).presence || user&.to_s }
  config.segments = ->(_request) { [] }
  config.mount_path = "/product_tours"
  config.rate_limit = { to: 60, within: 1.minute }
  config.accent_color = nil
  config.on_event = ->(_event) {}
  config.on_complete = ->(_progress) {}
end
```

- `enabled` gates end-user helpers, widget rendering, and public endpoints.
- `authorize_admin` gates the dashboard; development-only by default.
- `current_user` returns an object responding to `id`, or `nil`.
- `tenant` returns an opaque string key, or `nil` for a global installation.
- `author_label` / `visitor_label` store display labels for analytics.
- `segments` returns an array of strings, e.g. `["admin", "trial",
  "billing_incomplete"]`.
- `mount_path` must match the engine route.
- `rate_limit` uses Rails 7.2+ rate limiting; no-ops on 7.1.
- `accent_color` restyles widget controls with automatic contrast.
- `on_event` / `on_complete` run after the record is created; keep them fast.

## Data Model

Engine-prefixed table names.

### ProductTours::Tour

Fields: `key`, `status`, `kind`, `title`, `description`, `video_url`,
`embed_url`, `thumbnail_url`, `captions_url`, `provider`, `provider_id`,
`provider_title`, `media_kind`, `cta_label`, `cta_url`, `segments`, `trigger`,
`recurrence`, `priority`, `tenant`, `position`, `metadata`.

```ruby
enum :status, %w[draft published archived].index_by(&:itself)
enum :kind, %w[modal video embed checklist].index_by(&:itself)
enum :trigger, %w[manual success].index_by(&:itself)
enum :recurrence, %w[show_once until_completed always].index_by(&:itself)
```

Rules:

- `key` is stable and developer-facing.
- `published` tours are visible to eligible end users.
- `tenant` is opaque; `nil` = global.
- A single modal or video guide is a tour with one step; a multi-step modal has
  many. `checklist` arrives in v0.2.
- `video_url` is the pasted URL; `embed_url` the normalized player URL.
- `segments`, `recurrence` config, and `metadata` are JSON columns where
  supported, else Rails-serialized text.
- `recurrence`: `show_once` (default), `until_completed`, `always`.
- `trigger`: `manual` (helper/JS only) or `success` (queued by
  `product_tour_prompt!`, opened on the next eligible render). `auto` and
  `completion` are deferred.

Indexes: unique `[tenant, key]`; `status`; `kind`; `[tenant, status]`; `priority`.

### ProductTours::Step

Fields: `tour_id`, `key`, `position`, `title`, `body`, `video_url`, `cta_label`,
`cta_url`, `completion_key`, `metadata`.

Rules:

- Steps belong to a tour; `key` is stable within the tour.
- `completion_key` is optional and lets a step (or a v0.2 checklist item)
  complete from a host-side event.
- Steps render as pages of a centered modal; no positioning/anchoring.

Indexes: unique `[tour_id, key]`; `[tour_id, position]`; `completion_key`.

### ProductTours::Progress

Fields: `tour_id`, `tenant`, `author_id`, `visitor_token`, `status`,
`started_at`, `completed_at`, `dismissed_at`, `last_step_key`, `metadata`.

```ruby
enum :status, %w[not_started started dismissed completed].index_by(&:itself)
```

Rules: `author_id`/`visitor_token` are strings; signed-in progress keys by
`author_id`, anonymous by `visitor_token`. Supports show-once and
show-until-completed.

Indexes: `[tour_id, status]`; `[tenant, author_id, tour_id]`;
`[tenant, visitor_token, tour_id]`; `completed_at`.

### ProductTours::Event

Fields: `tour_id`, `step_id`, `action`, `tenant`, `author_id`, `author_label`,
`visitor_token`, `page_url`, `locale`, `metadata`.

```ruby
enum :action, %w[
  shown started viewed step_viewed dismissed completed cta_clicked
].index_by(&:itself)
```

Rules: `author_id`/`visitor_token` are strings; `page_url` strips query strings
by default; `metadata` is documented non-sensitive JSON only. (No `user_agent`
column — we don't store PII we never surface.)

Indexes: `[tour_id, action]`; `[step_id, action]`; `tenant`; `author_id`;
`visitor_token`; `created_at`.

## Multi-Tenancy

```ruby
config.tenant = ->(_request) { Current.organization&.to_gid&.to_s }
```

- Dashboard reads/writes tours for the current tenant; global tours have
  `tenant: nil`.
- A tenant-specific tour overrides a global tour with the same key; end-user
  helpers resolve tenant-specific first, then fall back to global.
- Progress and events are stamped with the current tenant.

Optional sugar, matching `has_testimonials` / `has_feedback`:

```ruby
class Organization < ApplicationRecord
  has_product_tours
end
```

## Eligibility, Targeting, And Recurrence

v0.1 targeting is deliberately small:

- tenant match
- status published
- segment intersection (`config.segments` ∩ tour `segments`; empty = all)
- recurrence

```ruby
segments: ["admin", "trial"]
recurrence: "until_completed"   # show_once | until_completed | always
trigger: "manual"               # manual | success
```

Rules:

- Empty `segments` means all segments.
- Explicit user action bypasses recurrence but not `enabled`, status, tenant, or
  segment eligibility.
- Default created tours are `manual` — no surprise auto-starts.

(No `page_rules` and no `auto` trigger in v0.1: manual and success-event guides
are placed exactly where the developer wants them, so path matching is
redundant until an `auto` mode exists.)

## View Helpers And JS API

```erb
<%= product_tours_tag %>
<%= product_tour_button(:billing_setup) %>
<%= product_tour_link(:billing_setup, "Watch setup guide") %>
<%= product_tour_embed(:billing_setup) %>
```

Behavior:

- Render nothing if the tour is missing, unpublished, disabled, or ineligible.
- `product_tours_tag` emits the JSON config and the same-origin widget script.
- Button/link helpers render the gem's own small, self-styled controls and open
  the guide without a full page reload.
- Embed helper renders an inline card/player.
- Opening a guide records `started`/`viewed`; each visible step records
  `step_viewed`; closing before completion records `dismissed`; CTA clicks record
  `cta_clicked`; finishing all required steps records `completed`.
- Closing a modal removes the player node so playback stops.

```js
window.ProductTours.open("billing_setup")
window.ProductTours.complete("billing_setup")
window.ProductTours.refresh()
```

The primary surface is the gem's helpers/widget; the JS API is for explicit
product events and custom flows.

## Dashboard

Mounted at `/product_tours`. Pages: guide index, new/edit/show guide, step
editor, event summary, progress summary. Index filters: status, kind, key,
tenant, segment, recently viewed.

- Development-only by default; host-configured admin gate for production.
- No host CSS dependency; self-contained light/dark theme via CSS custom
  properties; no inline handlers; same-origin fingerprinted `dashboard.js`.
- Preview video URLs on show/edit.
- "Fetch video data" uses provider/oEmbed metadata to prefill blank title,
  provider title, thumbnail, provider, provider id, and embed URL.
- Simple event counts per guide; a stale-guide warning when no events arrive
  recently.

## I18n

- Ship the same 26 locales as the sibling gems; every widget/dashboard string
  through `I18n.t` with an English default; RTL detection mirrors the family
  pattern.
- v0.1 stores guide content as plain strings; localized guide fields are v0.3.

## Privacy And Security

- Dashboard gated outside development; end-user write endpoints rate-limited.
- Never store full request params; strip query strings from `page_url`.
- Host user references are loose strings, not FKs.
- Never expose raw Active Storage blob URLs if uploads are added later.
- Same-origin scripts with request nonces; no inline handlers; escape `</` in
  JSON config script tags.
- Event metadata documented as non-sensitive.
- Ship `ProductTours::Event.prune(older_than:)` or a documented retention recipe
  before v1.0.

## Accessibility

- Buttons have labels and keyboard behavior.
- Modal uses `role="dialog"` + focus trap; Escape dismisses; controls reachable
  by keyboard; ARIA labels for next/previous/close/dismiss/progress.
- Respect `prefers-reduced-motion`.
- Never trap a user in a guide with no visible exit.

## Acceptance Criteria

- Fresh install works in a Rails 7.1+ dummy app; the generated initializer boots
  with safe defaults.
- Dashboard is inaccessible outside development unless `authorize_admin` allows.
- `product_tours_tag` serves same-origin JS with a content fingerprint; works
  under Turbo Drive and nonce-based CSP.
- `product_tour_button(:key)` renders only for a published, eligible tour and
  opens the guide without a full page reload.
- `product_tour_prompt!(:key)` opens the guide on the next eligible HTML render
  without a user click.
- `product_tour_embed(:key)` renders an inline player/card.
- A multi-step modal paginates and completes; Back/Next and progress work.
- Unsafe/unsupported video URLs never render an iframe; YouTube uses the nocookie
  host; Vimeo unlisted URLs keep their privacy hash; Voomly share/embed URLs
  render and record at least `viewed`.
- "Fetch video data" fills/suggests `provider_title`, `thumbnail_url`, and
  `embed_url` for YouTube/Vimeo without an API key; a failed fetch shows a help
  message but never blocks saving the URL.
- Opening records `started`/`viewed`; a step records `step_viewed`; closing
  unfinished records `dismissed`; closing stops playback (player node removed);
  CTA clicks record `cta_clicked`; completing records `completed` and updates
  progress.
- Tenant-specific tours override global tours with the same key; segment
  eligibility works from `config.segments`.
- Tests cover helpers, dashboard auth, guide lifecycle, step ordering, event
  recording, progress, tenant scoping, segment eligibility, video URL resolving,
  Turbo, and CSP.

## README Positioning

Hero: **Product tours for Rails.**

Subhead: Add guided onboarding, contextual help, video walkthroughs, and
checklists to your Rails app. Your app, your database, no third-party widget.

What you get:

|                | |
| -------------- | ------------------------------------------------------------------ |
| **Guides**     | Modal, video, and multi-step modal guides for onboarding and help  |
| **Checklists** | Setup tasks and adoption milestones (v0.2)                         |
| **Dashboard**  | Draft/publish/archive, step editor, usage and completion stats      |
| **Targeting**  | Tenant and host-defined segments                                    |
| **Storage**    | Ordinary Active Record rows in your database                        |
| **Deps**       | None. Plain JS — no Tailwind, Stimulus, importmap, or build step    |
| **Auth**       | Lambdas over the raw request: Devise, Rails 8 auth, anything        |
| **i18n**       | 26 languages, RTL included                                          |
| **Turbo/CSP**  | Turbo Drive and strict nonce-based CSP out of the box               |

Comparison:

|                        | `product_tours`     | Hardcoded help | Product-tour SaaS |
| ---------------------- | ------------------- | -------------- | ----------------- |
| Cost                   | Free, MIT           | Free           | Monthly/MAU based |
| Where guide data lives | Your database       | Code           | Vendor database   |
| Third-party script     | No                  | No             | Yes               |
| Rails user attribution | Server-side session | Manual         | Synced attrs      |
| Tenant scoping         | Built in            | Manual         | Often paid        |
| Admin-managed content  | Yes                 | No             | Yes               |
| Multi-step modals      | Yes                 | Custom JS      | Yes               |
| Checklists             | v0.2                | Custom code    | Yes               |
| Analytics/events       | In your DB          | Manual         | Vendor dashboard  |
| Data ownership         | Host-owned          | Host-owned     | Vendor-owned      |

README also includes: install; first guide in under 5 minutes; a success-event
prompt example; a multi-step modal example; a video-guide example; a Voomly
example; a checklist example once v0.2 ships; the config table; Devise and
Rails 8 auth examples; a multi-tenancy example; Turbo/CSP notes; screenshots/GIFs
of the modal, multi-step modal, video guide, and dashboard; and an explicit
"why not Appcues/Userflow/Chameleon/Pendo" section.

## Milestones

### v0.1 — Self-contained guide foundation

engine skeleton; install generator; initializer; migrations (tours, steps,
progress, events); `product_tours_tag`; `product_tour_button`/`_link`/`_embed`;
single modal, video, and multi-step modal guides; video resolver
(YouTube/Vimeo/Loom/Tella/Voomly/MP4) + YouTube/Vimeo oEmbed prefill;
`product_tour_prompt!`/`product_tour_complete!`; manual + success triggers;
event + progress recording; tenant scoping; segment eligibility; dashboard CRUD +
event/progress summary; Turbo/CSP-safe JS; 26 locales; Minitest + CI matrix;
README screenshots/GIFs.

### v0.2 — Checklists

`product_tour_checklist`; checklist items over existing steps; show-once /
show-until-completed; empty-state suppression; seed YAML import/export.

### v0.3 — Localization and media polish

localized guide fields; Active Storage uploads (using the upload-ready columns);
mobile polish.

### v0.4 — Guides launcher

optional `product_tours_guides` launcher; eligible guides/checklists list;
lightweight announcements-as-guides; retention/pruning helper.

### v1.0 — Public launch quality

optional authenticated/admin JSON endpoints (private by default, `testimonials`-
style opt-in only if a real host needs external rendering); upgrade guide; demo
app; polished README; screenshots + short demo video; one real Rails SaaS
adoption story; "good first issue" backlog.

## 5K-Star Strategy

- The first Rails-native Appcues/Userflow/Chameleon/Pendo alternative — minus the
  brittle DOM-anchoring, which is a feature, not a gap.
- Copy-paste install; a polished product in the README's first viewport.
- Emphasize: no third-party script, no MAU tax, no vendor database, no lock-in.
- Real screenshots, GIFs, and a demo app before broad launch.
- Comparison sections for the SaaS incumbents.
- Boring runtime: Rails, Active Record, plain JS.
- Easy contributor entry: documented architecture, small issues, clear tests.

## Risks And Open Questions

- **Scope creep.** Win by being the Rails-native 80%, not by copying enterprise
  features. (Anchoring, `auto`/`completion` triggers, `page_rules`, `context`,
  and analytics charts are already cut/deferred to hold the line.)
- **Demand is narrower than the other gems.** Product-tour content is less
  sensitive than chat/feedback/testimonials, so the self-host wedge leans on
  cost/lock-in rather than data ownership. Real, but thinner — sequence the easy,
  high-value core first and let a demo + screenshots carry the launch.
- **Auto-start annoyance.** Default to manual; `auto` stays deferred.
- **Stale content.** Dashboard shows last-viewed/last-completed so old guides are
  easy to retire.
- **Sensitive URLs.** Strip query strings; document event-metadata hygiene.
- **Name.** `product_tours` is descriptive, generic, and free on RubyGems as of
  2026-07-30.

## Success Criteria

- Fresh Rails app to first working guide in under 5 minutes.
- A developer adds a multi-step modal guide with one helper + dashboard content.
- A non-developer admin updates copy/video/CTA without a deploy.
- A multi-tenant SaaS scopes guides per tenant with one lambda.
- A strict-CSP host has zero console violations.
- The README makes the product visually obvious within the first screen.
- The gem can honestly say: "Use this when Appcues/Userflow/Chameleon/Pendo is
  too expensive, too external, or too much platform for a Rails app."
