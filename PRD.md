# PRD: product_tours

> Status: draft, revised 2026-07-31.
> Scope decision: `product_tours` ships individual invokable posts, not
> multi-step process tours. No DOM-anchored tooltips, no prev/next walkthroughs,
> no checklists in the first product.

## Summary

`product_tours` is a Rails engine for self-hosted in-app product guidance. The
core unit is a `ProductTours::Post`: one guidance item that the host app invokes
by key.

```ruby
gem "product_tours"
```

```erb
<%# app/views/layouts/application.html.erb, before </body> %>
<%= product_tours_tag %>

<%# Use your own UI to open a post in a modal %>
<button data-product-tour="billing_setup">Watch setup guide</button>
```

Product promise:

> Product tours for Rails. Add self-hosted in-app guidance posts to your app.
> Your UI, your database, no third-party widget.

## Core Decision

The gem deliberately avoids the two brittle parts of the product-tour category:

- No DOM-anchored tooltip tours. The gem never pins a popover to a host element.
- No multi-step prev/next walkthroughs. Each `Post` is an individual invokable
  unit.

This keeps the gem in the same reliable shape as the sibling gems: the engine
renders its own UI, stores its own rows, exposes small Rails helpers, and leaves
workflow orchestration to the host app.

## Positioning

**Self-hosted product guidance posts for Rails.** Developers place stable hooks
(`product_tours_tag`, helper buttons, success-event calls). Admins manage post
content from a mounted dashboard. End-user behavior is tracked in the host
database.

Intentionally different from hosted product-adoption platforms:

- The host app already knows the user, account, plan, role, flags, and lifecycle.
  Resolve them with request lambdas, not a synced customer database.
- The host app already has auth, tenancy, mailers, jobs, CSP, and I18n. Fit those
  systems instead of replacing them.
- Sibling gems own adjacent jobs. `testimonials`, `ideasbugs`, `livechat`, and
  `i18n_proofreading` keep their own workflows.

Tagline:

> `product_tours` - in-app guidance posts for Rails. Self-hosted, no third-party
> script, no MAU tax.

## Goals

- Install in under 5 minutes on a fresh Rails app.
- Rails 7.1+, Ruby 3.2+, mountable engine, isolated namespace `ProductTours`.
- Store posts and events in host-app tables.
- Invoke posts by stable developer-facing keys.
- Keep `key` unique per locale.
- Let admins edit title, rich description, optional video, CTA, status, and locale
  without a deploy.
- Let the host invoke posts after success events, not only button clicks.
- Support signed-in and anonymous visitors.
- Track views/completions by user, tenant, or user+tenant when the host provides
  those identifiers.
- Work with plain Rails views, Turbo Drive, and strict nonce-based CSP.
- No Tailwind, Stimulus, importmap, node, npm, CDN, or asset-pipeline
  assumptions.
- Enough analytics to answer: who saw this, who dismissed it, who completed it.

## Non-Goals

Absolute non-goals for v1:

- No DOM-anchored tooltip tours.
- No multi-step prev/next process tours.
- No `ProductTours::Step` model.
- No checklists.
- No external hosted service; no third-party tracking script.
- No syncing users/accounts into a vendor database.
- No visual builder, AI authoring, chatbot, or mobile SDK.
- No testimonial, feedback, bug, or support collection.
- No media creation; the gem accepts safe video URLs or uploaded videos.
- No enterprise workflow suite: roles, approvals, SAML, experiments, governance.
- Non-video file uploads outside Action Text attachments.

Deferred until real demand:

- Optional always-open resource center / guides launcher.
- Advanced analytics charts.
- Deep integrations with Segment, Amplitude, Mixpanel, Slack, etc.
- Automatic page-load invocation.

## Product Principles

- **Post, not process.** A `Post` is a single invokable guidance unit with one
  outcome.
- **Rails-native beats no-code.** The win is native placement, auth, tenancy,
  I18n, and persistence.
- **Self-contained UI.** The widget renders its own modal/card and never touches
  the host DOM.
- **Developer-placed, admin-managed.** Code defines where posts may appear;
  admins manage content and publishing.
- **Intent beats interruption.** Explicit clicks and success moments over
  surprise auto-starts.
- **Small frontend, strong backend.** Plain JS for modals/playback; Active Record
  for content and events.
- **Strict CSP is table stakes.** Same-origin scripts, nonce support, no inline
  handlers.

## Reference Gem Patterns To Reuse

Follow the shipped-gem house architecture:

- `isolate_namespace ProductTours`; `ProductTours::Configuration` PORO with safe
  defaults; `ProductTours.configure { |config| ... }`.
- Request-dependent lambdas receive the raw request.
- Dashboard access defaults to development only; public/user endpoints are
  independently gated by `enabled`.
- Loose host references in tracking rows: `author_id`, `visitor_token`, and
  `tenant` are strings, not foreign keys.
- Optional model concern via `ActiveSupport.on_load(:active_record)`; widget
  helper via `:action_view`; controller helper via `:action_controller`.
- Widget JS and dashboard JS live in `lib/product_tours/*.js`, served same-origin
  by the engine with content fingerprints.
- Helpers emit a `type="application/json"` config script plus a same-origin
  `defer` script.
- Runtime dependency: Rails only, unless overwhelmingly justified.
- Minitest, not RSpec; `test/dummy` app with fixed-nonce CSP tests.
- CI matrix: Rails 7.1/7.2/8.0/8.1 x Ruby 3.2/3.3/3.4.
- 26 locale files with a parity test.
- Mobile: full-screen modal at <=480px with the `visualViewport` keyboard fix,
  16px inputs, safe-area padding, contained overscroll.

## Core Product Surface

### 1. Post Library

A post is the base content unit. Product copy can still say "product tour", but
the primary Active Record model is `ProductTours::Post`.

v0.1 supports:

- custom UI invocation via `data-product-tour`
- inline rendering via `product_tour(:key)`
- title, optional rich description, optional video URL/upload, CTA label, and CTA
  URL
- `product_tour(:key)` for helper-rendered inline posts
- `product_tour_prompt!(key)` from controller code
- `shown` / `viewed` / `dismissed` / `completed` / `cta_clicked` events
- tracking by user, tenant, or user+tenant
- locale-specific records

There is no step editor, no Back/Next UI, and no post sequence in v0.1.

### 2. Post Rendering

Behavior:

- A post opens as one centered modal or renders as one inline card/player.
- Keyboard: Escape dismisses; Enter/Space activate controls; focus is trapped
  while the modal is open.
- Mobile: full-screen modal, keyboard-safe via `visualViewport`.
- A post with no renderable title/description/video does not open.
- Closing a modal removes the player node so playback stops.

All plain JS in the gem; no third-party overlay library, because there is no
positioning or sequence engine to solve.

### 3. Optional Video

Video is optional content on a post, not a separate post type. v0.1 supports:

- YouTube, Vimeo, Loom, Tella, Voomly, and direct MP4/WebM URLs.
- Active Storage video uploads via `has_one_attached :video`.

Resolver:

- A dedicated resolver object parses URLs and derives embeddable player URLs.
- Accept only HTTPS URLs from known provider hosts. Unsupported hosts, non-video
  paths, invalid URLs, lookalike hosts, and non-HTTPS schemes resolve to no
  embed.
- YouTube normalizes watch/shorts/live/embed/`youtu.be` to
  `youtube-nocookie.com/embed/<id>?rel=0&modestbranding=1`.
- Vimeo preserves unlisted privacy hashes.
- Loom, Tella, and Voomly are v0.1 providers because real launch content already
  lives there.
- Voomly accepts iframe embed URLs and share/embed URLs from Voomly's video
  drive; v0.1 treats it as an iframe player and records `viewed`.
- Direct video URLs and uploaded videos use a native `<video>` player.
- Record `completed` only where completion can be detected reliably; otherwise
  fall back to `viewed`/`dismissed`.
- Never record video in the browser.
- Non-video uploads are only supported inside Action Text attachments; no
  separate file-upload field ships in v0.1.

oEmbed is dashboard-only admin convenience:

- YouTube, Vimeo, Loom, Tella, and Voomly should all resolve safely in v0.1.
  oEmbed/prefill can start with providers that expose stable public metadata,
  but lack of metadata must never block saving or rendering a safe URL.
- "Fetch video data" prefills blank fields only: post title, provider title,
  thumbnail URL, provider, provider id, and embed URL.
- Never silently overwrite admin-edited fields.
- Network failure must never block saving a post.

### 4. Invocation

The post record stores content. The way it appears is decided by the invocation,
not by columns on `ProductTours::Post`.

Use `data-product-tour="key"` when the host app wants full control over button,
link, or icon styling. The widget listens for clicks on matching elements and
opens the current-locale published post in a modal.

```html
<button class="btn btn-primary" data-product-tour="billing_setup">
  Watch setup guide
</button>

<a href="#" data-product-tour="invite_team">Invite team walkthrough</a>
```

Use `product_tour(:key)` when the host wants the post rendered inline inside the
page:

```erb
<%= product_tour(:billing_setup) %>
```

`product_tour_prompt!(:key)` renders no UI. It queues modal invocation for the
next eligible HTML render. Use it after the host app knows something happened:

```ruby
class BillingController < ApplicationController
  def update
    # ...
    product_tour_prompt!(:invite_team)
    redirect_to billing_path
  end
end
```

- `product_tour_prompt!(key)` stores a flash-like signal for the next HTML render.
- Completion is not invoked manually from Rails app code. `completed` events are
  created by widget-side events, such as a completion action, reliable video
  completion, or another explicit end-user interaction.

## Installation

```bash
bundle add product_tours
bin/rails generate product_tours:install
bin/rails db:migrate
```

The installer creates an initializer, a migration, the engine mount route, and
post-install instructions. Default mount path `/product_tours`.

If Active Storage is not installed, the installer tells the host to run
`bin/rails active_storage:install` before using video uploads. If Action Text is
installed, posts expose `has_rich_text :description`; otherwise description is
disabled instead of falling back to a plain text column.

```erb
<%= product_tours_tag %>
```

Post-install output: run `rails db:migrate`; add `<%= product_tours_tag %>`
before `</body>`; manage posts at `/product_tours`; dashboard is
development-only until `config.authorize_admin` is set.

## Configuration

```ruby
ProductTours.configure do |config|
  config.enabled = ->(_request) { true }
  config.authorize_admin = ->(_request) { Rails.env.development? }
  config.current_user = ->(_request) {}
  config.tenant = ->(_request) {}
  config.locale = ->(_request) { I18n.locale }
  config.author_label = ->(user) { user.try(:name).presence || user.try(:email).presence || user&.to_s }
  config.visitor_label = ->(user) { user.try(:name).presence || user.try(:email).presence || user&.to_s }
  config.mount_path = "/product_tours"
  config.rate_limit = { to: 60, within: 1.minute }
end
```

- `enabled` gates end-user helpers, widget rendering, and public endpoints.
- `authorize_admin` gates the dashboard; development-only by default.
- `current_user` returns an object responding to `id`, or `nil`.
- `tenant` returns an opaque tracking key, or `nil` when tenant-level tracking is
  not needed.
- `locale` returns the lookup locale for `data-product-tour`, `product_tour(:key)`,
  and `product_tour_prompt!(:key)`; defaults to `I18n.locale`.
- `author_label` / `visitor_label` store display labels for analytics.
- `mount_path` must match the engine route.
- `rate_limit` uses Rails 7.2+ rate limiting; no-ops on 7.1.

## Data Model

Engine-prefixed table names.

### ProductTours::Post

Primary content record. This is the record looked up by `product_tour(:key)`,
`product_tour_prompt!(:key)`, and data-attribute modal triggers.

Fields: `key`, `locale`, `status`, `title`, `video_url`, `video_metadata`,
`cta_label`, `cta_url`, `priority`, `position`, `metadata`.

```ruby
enum :status, %w[draft published].index_by(&:itself)
```

Rules:

- `key` is stable, developer-facing, and supplied by the host app/user.
- `key` must match `/\A[a-z0-9]+(?:[._-][a-z0-9]+)*\z/`; examples:
  `billing_setup`, `invite.team`, `welcome-1`.
- The dashboard enforces the key format client-side while creating/editing posts,
  and the model enforces the same validation server-side.
- `locale` is required and defaults to `I18n.default_locale`.
- `key` is unique per `locale`; the same key may exist in multiple locales for
  translated post content.
- Helper lookup uses `config.locale` and does not silently fall back to another
  locale in v0.1.
- `title` is required.
- `description` is optional and exists only as `has_rich_text :description` when
  Action Text is available. There is no plain-text `description` column.
- If Action Text is unavailable, the dashboard hides the description editor and
  posts render with title/video/CTA only.
- `published` posts are visible to eligible end users.
- `video_url` is the pasted URL.
- `video_metadata` is JSON/JSONB and stores derived provider data such as
  `embed_url`, `thumbnail_url`, `captions_url`, `provider`, `provider_id`, and
  `provider_title`.
- `has_one_attached :video` supports uploaded video. Uploaded video wins at
  render time; `video_url` remains optional fallback/source metadata.
- Video source is computed at render time: uploaded video if attached, otherwise
  `video_url` if present.
- `metadata` is a JSON column where supported, else Rails-serialized text.
- There is no `display_mode` column; modal vs inline is an invocation choice.
- There is no `trigger` column; data-attribute modal, inline render, and prompted
  modal are invocation choices.

Indexes: unique `[locale, key]`; `locale`; `status`; `priority`.

### ProductTours::Post::Event

Fields: `post_id`, `action`, `tenant`, `author_id`, `author_label`,
`visitor_token`, `page_url`, `locale`, `metadata`.

```ruby
enum :action, %w[
  shown viewed dismissed completed cta_clicked
].index_by(&:itself)
```

Rules:

- `author_id`, `tenant`, and `visitor_token` are strings, not foreign keys.
- `belongs_to :post, class_name: "ProductTours::Post"`; events cannot exist
  without a post.
- `tenant` is tracking context only; it does not scope post content.
- `page_url` strips query strings by default.
- `metadata` is documented non-sensitive JSON only.
- No `user_agent` column.
- Viewed/completed state is derived from events instead of a separate progress
  table. Tenant-level questions like "has anyone in this tenant completed this
  post?" are answered by querying events.

Indexes: `[post_id, action]`; `tenant`; `author_id`; `visitor_token`;
`created_at`.

## Tracking Scope

```ruby
config.tenant = ->(_request) { Current.organization&.to_gid&.to_s }
```

- Posts are not tenant-scoped. A published post is one content record per
  locale/key.
- Events may be stamped with `author_id`, `visitor_token`, and `tenant`.
- Reporting must support user scope (`author_id`), tenant scope (`tenant`), and
  user+tenant scope (`author_id` + `tenant`).
- Tenant-level reporting answers questions like: "Has anyone in this tenant
  viewed or completed this post?"
- If the host does not provide a tenant, tracking still works by signed-in user
  or anonymous visitor token.

Optional sugar, matching `has_testimonials` / `has_feedback`:

```ruby
class Organization < ApplicationRecord
  has_product_tours
end
```

## Eligibility

v0.1 eligibility is deliberately small:

- status published

Rules:

- Posts never auto-start by themselves; they appear only through helper, JS, or
  queued prompt invocation.

No `page_rules` and no automatic page-load invocation in v0.1. Data-attribute
modal, inline, and server-prompted posts are placed exactly where the developer
wants them, so path matching is redundant.

## View Helpers And JS API

```erb
<%= product_tours_tag %>
<button data-product-tour="billing_setup">Watch setup guide</button>
<%= product_tour(:billing_setup) %>
```

Behavior:

- Render nothing if the post is missing, unpublished, or disabled.
- Data-attribute modal, inline helper, and prompt invocation all refuse
  unpublished posts. Unpublishing a post in the dashboard removes it from every
  host page without changing code at those invocation sites.
- `product_tours_tag` emits the JSON config and the same-origin widget script.
- Elements with `data-product-tour="key"` open the post in a modal without a full
  page reload and keep all styling in the host app.
- The `data-product-tour` value must use the same key format as `Post#key`.
- `product_tour(:key)` renders the post inline as a card/player.
- `product_tour_prompt!(:key)` renders no visible control; it asks the widget to
  open that post on the next eligible HTML page.
- Opening a post records `shown`/`viewed`; closing before completion records
  `dismissed`; CTA clicks record `cta_clicked`; completing records `completed`.
- Closing a modal removes the player node so playback stops.

The public surface is the gem's helpers, `data-product-tour` attributes, and
controller prompt helper. Completion is recorded by widget-side interactions, not
by a public Rails or JavaScript completion API.

## Dashboard

Mounted at `/product_tours`. Pages: post index, new/edit/show post, and event
summary. Post index filters: status, locale, key, recently viewed. Event filters
also include tenant and user.

- Development-only by default; host-configured admin gate for production.
- No host CSS dependency; self-contained light/dark theme via CSS custom
  properties; no inline handlers; same-origin fingerprinted `dashboard.js`.
- Preview video URLs and uploaded videos on show/edit.
- "Fetch video data" uses provider/oEmbed metadata to prefill blank title and
  store derived provider data in `video_metadata`.
- Simple event counts per post; stale-post warning when no events arrive
  recently.

## I18n

- Ship the same 26 locales as the sibling gems; every widget/dashboard string
  through `I18n.t` with an English default; RTL detection mirrors the family
  pattern.
- v0.1 stores localized post content as separate post records keyed by
  `[locale, key]`; localized field bundles are not needed.

## Privacy And Security

- Dashboard gated outside development; end-user write endpoints rate-limited.
- Never store full request params; strip query strings from `page_url`.
- Host user references are loose strings, not FKs.
- Never expose raw Active Storage blob URLs for uploaded videos or Action Text
  attachments.
- Same-origin scripts with request nonces; no inline handlers; escape `</` in
  JSON config script tags.
- Event metadata documented as non-sensitive.
- Ship `ProductTours::Post::Event.prune(older_than:)` or a documented retention
  recipe before v1.0.

## Accessibility

- Buttons have labels and keyboard behavior.
- Modal uses `role="dialog"` + focus trap; Escape dismisses; controls reachable
  by keyboard; ARIA labels for close/dismiss.
- Respect `prefers-reduced-motion`.
- Never trap a user in a post with no visible exit.

## Acceptance Criteria

- Fresh install works in a Rails 7.1+ dummy app; the generated initializer boots
  with safe defaults.
- Dashboard is inaccessible outside development unless `authorize_admin` allows.
- `ProductTours::Post` exists as the primary invokable model.
- `ProductTours::Post` has no `tenant` column; tenant is tracking context only.
- `ProductTours::Post` has no `display_mode` column and no `trigger` column.
- `ProductTours::Post` has no plain-text `description` column. Description is
  `has_rich_text :description` only when Action Text is available.
- Provider/oEmbed data is stored in `video_metadata`, not one column per provider
  attribute.
- `ProductTours::Post.status` has only `draft` and `published`.
- `ProductTours::Post.key` is validated server-side and client-side with
  `/\A[a-z0-9]+(?:[._-][a-z0-9]+)*\z/`.
- There is no `ProductTours::Step` model and no prev/next modal flow.
- `product_tours_tag` serves same-origin JS with a content fingerprint; works
  under Turbo Drive and nonce-based CSP.
- Elements with `data-product-tour="key"` open the current-locale published post
  in a modal without a full page reload.
- `product_tour(:key)`, `product_tour_prompt!`, and data-attribute triggers render
  or open nothing when the post is not `published`.
- `product_tour_prompt!(:key)` opens the post on the next eligible HTML render
  without a user click.
- `product_tour(:key)` renders the current-locale post inline.
- There is no Rails-side `product_tour_complete!(key)` API; completion is
  recorded from widget events.
- Unsafe/unsupported video URLs never render an iframe; YouTube uses the nocookie
  host; Vimeo unlisted URLs keep their privacy hash; Voomly share/embed URLs
  render and record at least `viewed`.
- Loom, Tella, and Voomly URLs resolve safely in v0.1.
- Uploaded videos render through a native `<video>` player.
- "Fetch video data" stores provider metadata in `video_metadata` where provider
  metadata is available; a failed fetch shows a help message but never blocks
  saving the URL.
- Opening records `shown`/`viewed`; closing unfinished records `dismissed`;
  closing stops playback; CTA clicks record `cta_clicked`; completing records
  `completed`.
- The same key can exist in different locales; helper lookup uses `config.locale`
  and does not silently fall back to another locale in v0.1.
- Tests cover helpers, dashboard auth, post lifecycle, event recording,
  user/tenant tracking scopes, key validation, published-only rendering, video URL
  resolving, video uploads, Turbo, and CSP.

## README Positioning

Hero: **Product tours for Rails.**

Subhead: Add self-hosted onboarding notes and contextual help to your Rails app.
Your app, your database, no third-party widget.

What you get:

|                | |
| -------------- | ------------------------------------------------------------------ |
| **Posts**      | Guidance posts opened by data attribute or rendered inline by helper |
| **Dashboard**  | Draft/publish, usage and completion stats                          |
| **Tracking**   | User, tenant, and user+tenant event scope                          |
| **Storage**    | Ordinary Active Record rows in your database                       |
| **Deps**       | None. Plain JS - no Tailwind, Stimulus, importmap, or build step   |
| **Auth**       | Lambdas over the raw request: Devise, Rails 8 auth, anything       |
| **i18n**       | Locale-specific posts, 26 UI locales, RTL included                 |
| **Turbo/CSP**  | Turbo Drive and strict nonce-based CSP out of the box              |

Comparison:

|                        | `product_tours`     | Hardcoded help | Product-tour SaaS |
| ---------------------- | ------------------- | -------------- | ----------------- |
| Cost                   | Free, MIT           | Free           | Monthly/MAU based |
| Where post data lives  | Your database       | Code           | Vendor database   |
| Third-party script     | No                  | No             | Yes               |
| Rails user attribution | Server-side session | Manual         | Synced attrs      |
| Tenant-aware tracking  | Built in            | Manual         | Often paid        |
| Admin-managed content  | Yes                 | No             | Yes               |
| Multi-step tours       | No                  | Custom JS      | Yes               |
| Checklists             | No                  | Custom code    | Yes               |
| Analytics/events       | In your DB          | Manual         | Vendor dashboard  |
| Data ownership         | Host-owned          | Host-owned     | Vendor-owned      |

README also includes: install; first post in under 5 minutes; a
`data-product-tour` button example; a success-event prompt example; the config
table; Devise and Rails 8 auth examples; a tracking-scope example; Turbo/CSP
notes; screenshots/GIFs of the modal, inline embed, and dashboard; and an
explicit "why not Appcues/Userflow/Chameleon/Pendo" section.

## Milestones

### v0.1 - Individual invokable posts

Engine skeleton; install generator; initializer; migrations (posts, post-events);
`product_tours_tag`; `data-product-tour`; `product_tour(:key)`; modal and inline
invocation;
video URL resolver
(YouTube/Vimeo/Loom/Tella/Voomly/MP4) + safe metadata prefill where available;
`product_tour_prompt!`; visible and prompted invocation; event recording;
user/tenant/user+tenant tracking scopes;
uploaded videos; Action Text description when available; dashboard CRUD +
event summary; Turbo/CSP-safe JS; 26 locales; Minitest and CI matrix;
README screenshots/GIFs.

### v0.2 - Polish from real usage

admin bulk actions; import/export; retention/pruning helper; README demo app.

### v1.0 - Public launch quality

Upgrade guide; polished README; screenshots + short demo video; one real Rails
SaaS adoption story; "good first issue" backlog.

## Risks And Open Questions

- **Scope creep.** The product is posts, not a workflow builder. Steps,
  checklists, launchers, anchoring, automatic page-load invocation, page rules,
  and analytics charts stay out until real usage proves they are worth the cost.
- **Demand is narrower than the other gems.** Product-tour content is less
  sensitive than chat/feedback/testimonials, so the self-host wedge leans on
  cost/lock-in and Rails-native control.
- **Auto-start annoyance.** Automatic page-load invocation stays deferred.
- **Stale content.** Dashboard derives last-viewed/last-completed from events so
  old posts are easy to retire.
- **Sensitive URLs.** Strip query strings; document event-metadata hygiene.
- **Name.** `product_tours` is descriptive, generic, and free on RubyGems as of
  2026-07-30.

## Success Criteria

- Fresh Rails app to first working post in under 5 minutes.
- A developer adds an invokable modal post with one helper + dashboard content.
- A non-developer admin updates title/description/video/CTA without a deploy.
- A SaaS app tracks whether a post was viewed/completed by a user, a tenant, or a
  user within a tenant.
- A strict-CSP host has zero console violations.
- The README makes the product visually obvious within the first screen.
- The gem can honestly say: "Use this when Appcues/Userflow/Chameleon/Pendo is
  too expensive, too external, or too much platform for a Rails app."
