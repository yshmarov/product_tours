# PRD: product_tours

> Status: implemented, revised 2026-08-03.
> Scope decision: `product_tours` ships individual invokable posts that may link
> to another post. It has lightweight Next/Back navigation, but no grouped tour
> model, DOM-anchored tooltips, ordered step builder, or checklists.

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

## Core Decision

The gem deliberately avoids the brittle parts of the product-tour category:

- No DOM-anchored tooltip tours. The gem never pins a popover to a host element.
- No persisted sequence or ordered step builder. Each `Post` remains an
  individual invokable unit, but its primary action may open another Post in the
  same modal. The widget derives Back navigation from its in-memory history.

This keeps the gem in the same reliable shape as the sibling gems: the engine
renders its own UI, stores its own rows, exposes a small Rails helper, and leaves
workflow orchestration to the host app.

## Goals

- Install in under 5 minutes on a fresh Rails app.
- Rails 7.1+, Ruby 3.2+, mountable engine, isolated namespace `ProductTours`.
- Store posts in host-app tables.
- Invoke posts by stable developer-facing keys.
- Keep `key` unique per locale.
- Let admins edit title, optional rich description when Action Text is available,
  optional video, primary action, status, and locale without a deploy.
- Support signed-in and anonymous visitors.
- Emit small lifecycle signals without persisting analytics or user identity.
- Work with plain Rails views, Turbo Drive, and strict nonce-based CSP.
- No Tailwind, Stimulus, importmap, node, npm, CDN, or asset-pipeline
  assumptions.
- Enough instrumentation for a host app to attach its own request context and
  answer who saw, dismissed, or completed a tutorial.

## Non-Goals

Absolute non-goals:

- No DOM-anchored tooltip tours.
- No persisted or automatically ordered process tours.
- No `ProductTours::Step` model.
- No checklists.
- No external hosted service; no third-party tracking script.
- No syncing users/accounts into a vendor database.
- No visual builder, AI authoring, chatbot, or mobile SDK.
- No testimonial, feedback, bug, or support collection.
- No gem-owned resource center, guides launcher, or host navigation UI.
- No gem-managed page rules or automatic display scheduling. The host app may
  invoke a Post on load using the same `data-product-tour` contract.
- No analytics persistence, analytics dashboard, or Ahoy dependency.
- No direct Segment, Amplitude, Mixpanel, Slack, or other vendor integrations.
- No media creation; the gem accepts safe video URLs or uploaded videos.
- No enterprise workflow suite: roles, approvals, SAML, experiments, governance.
- No non-video file uploads outside Action Text attachments.

## Product Principles

- **Post, not process.** A `Post` is a single invokable guidance unit with one
  outcome.
- **Rails-native beats no-code.** The win is native placement, auth, tenancy,
  I18n, and persistence.
- **Self-contained UI.** The widget renders its own modal; it does not anchor
  itself to host DOM elements.
- **Developer-placed, admin-managed.** Code defines where posts may appear;
  admins manage content and publishing.
- **The host decides timing.** The same explicit trigger contract supports a
  user click, a Stimulus controller, or Rails-rendered flash state; the gem does
  not invent page rules.
- **Small frontend, strong backend.** Plain JS for modals/playback; Active Record
  for content; `ActiveSupport::Notifications` lets the host choose whether and
  where lifecycle signals are persisted.
- **Strict CSP is table stakes.** Same-origin scripts, nonce support, no inline
  handlers, and automatic merging of supported provider origins into an
  existing Rails `frame-src` policy.

## Reference Gem Patterns To Reuse

Sibling gems reviewed: `livechat`, `testimonials`, `ideasbugs`, and
`i18n_proofreading`. `product_tours` should feel like the same family: install
generator, isolated Rails engine, request lambdas, same-origin widget script,
development-only dashboard by default, plain JS, Minitest, dummy app, and locale
parity.

The modal shell follows the shared `testimonials`/`ideasbugs` visual language:
compact centered card, 14px radius, 20px padding, plain header close button,
blue primary and outlined secondary actions, matching light/dark tokens, and an
animation-free full-screen mobile layout. Product-specific content may add a
16:9 media region and Back/Next navigation without introducing another modal
design system.

Adopt:

- `isolate_namespace ProductTours`; `ProductTours::Configuration` PORO with safe
  defaults; `ProductTours.configure { |config| ... }`.
- Top-level module methods: `config`, `configure`, `enabled?(request)`,
  `admin?(request)`, and `locale(request)`.
- Request-dependent lambdas receive the raw request.
- Dashboard access defaults to development only; public/user endpoints are
  independently gated by `enabled`.
- Lifecycle payloads describe the tutorial interaction only. Host subscribers
  may attach Current/Ahoy identity or account context.
- `mount_product_tours at: "/product_tours"` route helper that also updates
  `ProductTours.config.mount_path`.
- Widget helper via `ActiveSupport.on_load(:action_view)`.
- Widget JS and dashboard JS live under `lib/product_tours/`, served same-origin
  by the engine with content fingerprints.
- `product_tours_tag` emits a `type="application/json"` config script plus a
  same-origin `defer` script.
- Runtime dependency: Rails only, unless overwhelmingly justified.
- Minitest, not RSpec; `test/dummy` app with fixed-nonce CSP tests.
- CI matrix: Rails 7.1/7.2/8.0/8.1 x Ruby 3.2/3.3/3.4.
- 26 locale files with a parity test.
- Mobile: full-screen modal at <=480px with the `visualViewport` keyboard fix,
  16px inputs, safe-area padding, contained overscroll.

Do not copy:

- `testimonials` prompt recurrence, NPS, public collection page, read API, and
  `has_testimonials` content scoping.
- `ideasbugs` tenant-scoped content board and `has_feedback` model macro.
- `livechat` floating launcher, accent color, mailers, Action Cable, inbox
  workflow, and public `window.Livechat.open()` API.
- `i18n_proofreading` middleware auto-injection and I18n backend patching.

## Execution Recipe

Build in this order.

1. Engine skeleton:
   `lib/product_tours.rb`, `lib/product_tours/version.rb`,
   `lib/product_tours/configuration.rb`, `lib/product_tours/engine.rb`,
   `app/models/product_tours/application_record.rb`, and
   `app/controllers/product_tours/application_controller.rb`.
2. Engine hooks:
   isolate namespace, include `ProductTours::WidgetHelper` into Action View, and
   add `mount_product_tours` to the host router.
3. Install generator:
   copy `config/initializers/product_tours.rb`, create one migration for posts,
   seed current-locale demos during development migration, mount the engine at
   `/product_tours`, and print a copy-ready ERB trigger block plus exact next
   steps. Run Active Storage / Action Text installers only if the host wants
   those features.
4. Configuration:
   implement `enabled`, `authorize_admin`, `admin_layout`, `mount_path`, and
   `storage_service`. Locale lookup follows `I18n.locale` with a default-locale
   fallback. Add strict unresolved-trigger handling that raises in
   development/test and reports in production. No accent color, no callbacks, no
   prompt settings.
5. Data model:
   create `ProductTours::Post`; validate statuses, key format, `[locale, key]`
   uniqueness, and action URL safety. Add `has_rich_text :description` only when
   Action Text is loaded and `has_one_attached :video` only when Active Storage is
   loaded.
6. Widget asset serving:
   implement `ProductTours::Widget` with `widget.js`, `dashboard.js`, and
   `dashboard.css` sources, MD5 fingerprints, RTL detection, I18n labels with
   English defaults, JSON config escaping, and nonce-aware same-origin script
   tags.
7. Routes and controllers:
   expose `widget.js`, `dashboard.js`, `dashboard.css`; add public endpoints for
   current-locale published post lookup, unresolved-trigger reporting, and
   lifecycle signal instrumentation; add dashboard CRUD for posts; serve uploaded
   videos through gated engine routes instead of raw blob URLs.
8. Invocation:
   `product_tours_tag` installs the widget; elements with
   `data-product-tour="key"` open a modal. Missing, disabled, unpublished, or
   invalid triggers open nothing for the user but raise/report a Rails-side
   unresolved-trigger error.
9. Video resolver:
   build a small object that accepts HTTPS YouTube, Vimeo, Loom, Tella, Voomly,
   and direct MP4/WebM URLs; returns an embeddable source or nil; stores derived
   metadata in `video_metadata`; fails closed for unsupported URLs.
10. Dashboard:
   use `admin_layout`, development-only access by default, post filters, post
   CRUD, a default-locale canonical sidebar with
   translation creation from each tutorial,
   client-side key normalization, immediate oEmbed-backed video preview,
   best-effort "Fetch video data", and same-origin dashboard assets.
11. Tests:
   cover generator output, route helper mount path syncing, configuration
   defaults, tag helper rendering, same-origin asset fingerprints, Turbo/CSP behavior,
   post validations, published-only modal opening, minimal lifecycle instrumentation,
   current/default locale fallback behavior, video resolver safety,
   uploaded video serving, Action Text present/absent behavior, dashboard auth,
   and locale parity.

## Core Product Surface

### 1. Post Library

A post is the base content unit. Product copy can still say "product tour", but
the primary Active Record model is `ProductTours::Post`.

v0.1 supports:

- custom UI invocation via `data-product-tour`
- title, optional rich description when Action Text is available, optional video
  URL/upload, action label, and action URL
- `viewed` / `dismissed` / `completed` lifecycle signals
- lifecycle payloads without gem-owned identity or analytics state
- locale-specific records

There is no step editor or persisted sequence. A Post may link to another Post;
the widget supplies Next/Back behavior from that lightweight relationship.

### 2. Post Rendering

Behavior:

- A post opens as one centered modal.
- Keyboard: Escape dismisses; Enter/Space activate controls; focus is trapped
  while the modal is open.
- Mobile: full-screen modal, keyboard-safe via `visualViewport`.
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
- Loom, Tella, and Voomly are v0.1 providers because existing user videos already
  live there.
- Voomly accepts iframe embed URLs and share/embed URLs from Voomly's video
  drive; v0.1 treats it as an iframe player and emits `viewed` when visible.
- Direct video URLs and uploaded videos use a native `<video>` player.
- Emit `completed` only where completion can be detected reliably; otherwise fall
  back to `viewed` and, for modals, `dismissed`.
- Never record video in the browser.
- Non-video uploads are only supported inside Action Text attachments; no
  separate file-upload field ships in v0.1.

Video metadata fetching is dashboard-only admin convenience:

- YouTube, Vimeo, Loom, Tella, and Voomly should all resolve safely in v0.1.
  Metadata prefill can start with providers that expose stable public metadata,
  but lack of metadata must never block saving or rendering a safe URL.
- "Fetch video data" may prefill a blank post title from provider metadata.
- Provider title, thumbnail URL, provider, provider id, and embed URL are stored
  in `video_metadata` when available.
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

- Completion is not invoked manually from Rails app code. `completed` signals are
  created by widget-side behavior, such as a built-in completion action or
  reliable native video completion.

## Installation

```bash
bundle add product_tours
bin/rails generate product_tours:install
bin/rails db:migrate
```

The installer creates an initializer, a migration, the engine mount route, and
post-install instructions. In development, the migration also creates an
idempotent provider demo collection linked into one walkthrough covering
YouTube, Vimeo, Loom, Tella, Voomly, and direct video in the app's default
locale. The printed demo launchers also include a seeded draft key and a key
that deliberately does not exist, so unresolved-trigger behavior is testable
immediately. Production migrations never create demo content. Default mount
path `/product_tours`.

If Active Storage is not installed, the installer tells the host to run
`bin/rails active_storage:install` before using video uploads. If Action Text is
installed, posts expose `has_rich_text :description`; otherwise description is
disabled instead of falling back to a plain text column.

```erb
<%= product_tours_tag %>
```

Post-install output: run `rails db:migrate`; copy the printed ERB buttons and
`product_tours_tag` into a view; manage tutorials at `/product_tours`; dashboard is
development-only until `config.authorize_admin` is set. The seed rake task
refreshes English, French, and Bulgarian demos and prints the same block.

## Configuration

```ruby
ProductTours.configure do |config|
  config.enabled = ->(_request) { true }
  config.authorize_admin = ->(_request) { Rails.env.development? }
  config.admin_layout = "product_tours/application"
  config.mount_path = "/product_tours"
  config.storage_service = nil
end
```

- `enabled` gates the end-user helper, widget rendering, and public endpoints.
- `authorize_admin` gates the dashboard; development-only by default.
- `admin_layout` renders the dashboard inside the gem layout by default; hosts can
  point it at their admin shell.
- Tutorial lookup uses the page's current `I18n.locale` and falls back to
  `I18n.default_locale` only when the requested-locale record does not exist.
- `mount_path` must match the engine route.
- `storage_service` optionally names an Active Storage service for uploaded videos.
- Invalid/missing/unpublished triggers raise in development/test. Production
  reports a handled exception through `Rails.error`, instruments the failure,
  and returns a non-user-facing 404. This behavior is intentionally not configurable.

## Data Model

Engine-prefixed table names.

### ProductTours::Post

Primary content record. This is the record looked up by data-attribute modal
triggers.

Fields: `key`, `locale`, `status`, `title`, `video_url`, `video_metadata`,
`action_label`, `action_url`, `action_post_key`.

```ruby
enum :status, %w[draft published].index_by(&:itself)
```

Rules:

- `key` is stable, developer-facing, and supplied by the host app.
- `key` must match `/\A[a-z0-9]+(?:[._-][a-z0-9]+)*\z/`; examples:
  `billing_setup`, `invite.team`, `welcome-1`.
- The dashboard enforces the key format client-side while creating/editing posts,
  and the model enforces the same validation server-side.
- `locale` is required and defaults to `I18n.default_locale`.
- `key` is unique per `locale`; the same key may exist in multiple locales for
  translated post content.
- The dashboard lists only default-locale records. New product tour creates are
  forced to the default locale; translations are draft copies added from the
  tutorial detail and grouped by the same key without a separate translation
  or course model.
- Locale is fixed after creation. A translated record's key, and a default
  record's key once translations exist, are fixed in the editor so the group
  cannot be orphaned accidentally.
- Helper lookup uses the current locale and falls back to the default locale when
  no current-locale record exists. A draft current-locale record is not bypassed.
- `title` is required.
- `description` is optional and exists only as `has_rich_text :description` when
  Action Text is available. There is no plain-text `description` column.
- If Action Text is unavailable, the dashboard hides the description editor and
  posts render with title/video/action only.
- `published` posts are visible to end users.
- `video_url` is the pasted URL.
- `video_metadata` is JSON/JSONB and stores derived provider data such as
  `embed_url`, `thumbnail_url`, `captions_url`, `provider`, `provider_id`, and
  `provider_title`.
- `has_one_attached :video` supports uploaded video. Uploaded video wins at
  render time; `video_url` remains optional fallback/source metadata.
- Uploaded videos use `ProductTours.config.storage_service` when set; nil falls
  through to the host app's default Active Storage service.
- Video source is computed at render time: uploaded video if attached, otherwise
  `video_url` if present.
- There is no `display_mode` column; posts always render in the widget modal.
- There is no `trigger` column; the trigger is the host element with
  `data-product-tour`.
- `action_url` and `action_post_key` are mutually exclusive. A linked Post must
  exist in the same locale and cannot link to itself.

Indexes: unique `[locale, key]`; `locale`; `status`.

## Lifecycle Instrumentation

The gem does not create a `ProductTours::Post::Event` table in v0.1. Lifecycle
signals are not persisted by the gem. The widget reports meaningful client-side
signals to the engine, and the engine emits small Rails instrumentation events.
The host subscriber can attach its own Current/Ahoy identity and account context.

Signals:

```ruby
viewed
dismissed
completed
```

Rules:

- Do not emit a signal merely because a post was rendered by Rails or returned by
  an endpoint.
- `viewed` means the widget has client-side evidence that the modal was inserted,
  visible, and focused after a user click. A click on `data-product-tour` alone is
  not enough.
- `dismissed` is modal-only and emits when the user closes the modal before a
  `completed` signal.
- The widget renders at most one primary action. It closes the modal, follows
  `action_url`, or opens `action_post_key` in place. Linked navigation adds the
  previous Post to an in-memory Back stack.
- Clicking a URL/close action emits `completed` with source `action`. A linked
  action resolves its target first, then emits completion with source
  `linked_post` and swaps the modal content.
- `completed` consistently means that the visitor used the tutorial's primary
  action. Video playback does not emit completion because provider support is
  inconsistent.
- The server validates the signal action, finds the published tutorial by key and
  resolved locale, strips query strings from `page_url`, and emits
  `ActiveSupport::Notifications`.
- Instrumentation names: `product_tours.viewed`, `product_tours.dismissed`, and
  `product_tours.completed`.
- Payload keys: `post_id`, `key`, `locale`, `page_url`, and `source`.
- No `user_agent` payload.
- If the host does not subscribe to the notifications, the signals are simply not
  persisted.

Example Ahoy bridge:

```ruby
ActiveSupport::Notifications.subscribe(/^product_tours\./) do |name, _start, _finish, _id, payload|
  Ahoy.track(
    name.delete_prefix("product_tours."),
    payload.slice(:key, :locale, :source)
  )
end
```

## Visibility

v0.1 visibility is deliberately small:

- status published

Rules:

- Posts never schedule themselves. The host decides when to activate a
  `data-product-tour` element, including after page load when appropriate.

There are no gem-owned `page_rules`. A host can render and click a hidden trigger
from Stimulus, use Rails flash state to select a key, or compose triggers into its
own Help menu. Path matching and display policy stay in application code.

## Unresolved Triggers

A host-visible element with `data-product-tour="key"` is a code/content contract.
If the key is invalid, missing for the current locale, unpublished, or unavailable
because the gem is disabled for the request, the gem treats that as a host
configuration error.

Rules:

- The widget always asks the engine to resolve the key before opening the modal.
- The server validates the key format with the same regex as `Post#key`.
- The server resolves the current locale first and the default locale second,
  then opens only the resolved `published` tutorial.
- The user-facing page fails closed: no modal opens and no lifecycle signal is
  emitted.
- The Rails app gets a loud signal: `ProductTours::UnresolvedTriggerError` in
  development/test; production uses `Rails.error.report` with `handled: true`,
  an error log fallback, and
  `ActiveSupport::Notifications.instrument("product_tours.unresolved_trigger")`.
- Error payload keys: `key`, `locale`, `reason`, and `page_url`.
- Reasons: `invalid_key`, `missing`, `unpublished`, `disabled`.
- The widget may also write a `console.error` in development when the request
  returns an unresolved-trigger response.

## View Helper And Widget

```erb
<%= product_tours_tag %>
<button data-product-tour="billing_setup">Watch setup guide</button>
```

Behavior:

- Open nothing for the user if the post is missing, unpublished, disabled, or the
  key is invalid.
- Data-attribute modal invocation refuses unpublished posts. Unpublishing a post
  in the dashboard removes it from every host page without changing code at those
  invocation sites.
- Invalid, missing, unpublished, or disabled triggers raise/report through
  unresolved-trigger handling instead of failing silently.
- `product_tours_tag` emits the JSON config and the same-origin widget script.
- Elements with `data-product-tour="key"` open the post in a modal without a full
  page reload and keep all styling in the host app.
- The `data-product-tour` value must use the same key format as `Post#key`.
- Visible modals emit `viewed`; closing a modal before completion emits
  `dismissed`; the primary action emits `completed`.
- Closing a modal removes the player node so playback stops.

The public surface is `product_tours_tag` and `data-product-tour` attributes. The
widget reports lifecycle signals through engine endpoints, but does not expose a
public Rails or JavaScript completion API. Help menus and resource-center-style
launchers are ordinary host UI composed from the same trigger attributes.

## Dashboard

Mounted at `/product_tours`. Pages: tutorial index, new/edit/show tutorial. The
sidebar shows only `I18n.default_locale` records and filters by status and key.
Existing and missing translations are managed from each tutorial detail.

- Development-only by default; host-configured admin gate for production.
- No host CSS dependency; self-contained light/dark theme via CSS custom
  properties; no inline handlers; same-origin fingerprinted `dashboard.js`.
- Preview video URLs and uploaded videos on show/edit. Pasted URLs resolve after
  a short debounce; direct videos seek to an early frame for a useful poster-like
  preview without generating or storing a derived image.
- "Fetch video data" uses provider metadata to prefill a blank title and store
  derived provider data in `video_metadata`.

## I18n

- Ship the same 26 locales as the sibling gems; every widget/dashboard string
  through `I18n.t` with an English default; RTL detection mirrors the family
  pattern.
- v0.1 stores localized post content as separate post records keyed by
  `[locale, key]`; localized field bundles are not needed.

## Privacy And Security

- Dashboard gated outside development; public endpoints perform indexed reads
  and notification emission only. Host-wide request throttling belongs at the
  application/proxy layer.
- Never store full request params; strip query strings from `page_url`.
- The gem stores no visitor identity or tenant context.
- Action URLs allow only HTTP(S) URLs or relative paths.
- Never expose raw Active Storage blob URLs for uploaded videos or Action Text
  attachments.
- Same-origin scripts with request nonces; no inline handlers; escape `</` in
  JSON config script tags.
- Lifecycle payloads contain only the documented tutorial and page context.

## Accessibility

- Gem-rendered controls have labels and keyboard behavior.
- Modal uses `role="dialog"` + focus trap; Escape dismisses; controls reachable
  by keyboard; ARIA labels for close/dismiss.
- Respect `prefers-reduced-motion`.
- Never trap a user in a post with no visible exit.

## Acceptance Criteria

- Fresh install works in a Rails 7.1+ dummy app; the generated initializer boots
  with safe defaults.
- A development migration seeds provider demos and a linked walkthrough; the
  installer prints entry buttons that can be pasted into an ERB view.
- Dashboard is inaccessible outside development unless `authorize_admin` allows.
- `ProductTours::Post` exists as the primary invokable model.
- `ProductTours::Post` has no `tenant` column and configuration has no identity
  or tenant hooks.
- There is no `ProductTours::Post::Event` model and no generated event table.
- The gem does not persist lifecycle analytics; it emits
  `ActiveSupport::Notifications` for host analytics tools such as Ahoy.
- `ProductTours::Post` has no `display_mode` column and no `trigger` column.
- `ProductTours::Post` has no plain-text `description` column. Description is
  `has_rich_text :description` only when Action Text is available.
- Provider metadata is stored in `video_metadata`, not one column per provider
  attribute.
- `ProductTours::Post.status` has only `draft` and `published`.
- `ProductTours::Post.key` is validated server-side and client-side with
  `/\A[a-z0-9]+(?:[._-][a-z0-9]+)*\z/`.
- There is no `ProductTours::Step` or grouping model. Linked Posts provide
  Next/Back navigation without persisted ordering or progress.
- `product_tours_tag` serves same-origin JS with a content fingerprint; works
  under Turbo Drive and nonce-based CSP.
- Elements with `data-product-tour="key"` open the current-locale published post,
  or its default-locale fallback, in a modal without a full page reload.
- Data-attribute triggers open nothing when the key is invalid or the post is
  missing, unpublished, or disabled, and the Rails app receives an
  unresolved-trigger error/report with a reason.
- There is no Rails-side `product_tour_complete!(key)` API; completion is emitted
  from widget lifecycle signals.
- There is no `shown` event. `viewed` is the first exposure event and requires the
  modal to be visible and focused.
- Unsafe/unsupported video URLs never render an iframe; YouTube uses the nocookie
  host; Vimeo unlisted URLs keep their privacy hash; Voomly share/embed URLs
  render and emit at least `viewed`.
- Loom, Tella, and Voomly URLs resolve safely in v0.1.
- Uploaded videos render through a native `<video>` player.
- "Fetch video data" stores provider metadata in `video_metadata` where provider
  metadata is available; a failed fetch shows a help message but never blocks
  saving the URL.
- Visible modals emit `viewed`; closing unfinished modals emits `dismissed`;
  closing stops playback; the primary action emits `completed`.
- The same key can exist in different locales; trigger lookup tries the page's
  current locale and then `I18n.default_locale` when no translation exists.
- Tests cover the tag helper, dashboard auth, post lifecycle, lifecycle instrumentation
  payloads, key validation, published-only modal opening, viewed modal visibility,
  video URL resolving, video uploads, Turbo, and CSP.

## Linked Posts

Linked posts provide lightweight next/back behavior
without turning the gem into a process-tour builder.

Behavior:

- A post still has one primary action.
- The primary action can either follow `action_url` or open another published post
  by key.
- `action_post_key` stores the destination; lookup stays in the current locale.
- At most one target is allowed: `action_url` or `action_post_key`.
- If the action opens another post, the widget swaps modal content in place.
- The widget keeps an in-memory back stack for a Back control.
- No `ProductTours::Step` model, no persisted sequence, no ordered tour builder,
  and no automatic prev/next flow.
- Lookup remains stable by locale + key. Arbitrary params should not decide which
  post is loaded.
- Linked navigation does not add lifecycle metadata or create a hidden state
  machine.
- Invalid/missing/unpublished linked-post targets use the same unresolved-trigger
  error handling as `data-product-tour`.

## Risks And Open Questions

- **Scope creep.** The product is posts, not a workflow builder or engagement
  platform. Steps, checklists, launchers, anchoring, page rules, analytics
  persistence, and vendor integrations remain host-app responsibilities.
- **Sensitive URLs.** Strip query strings; document lifecycle-metadata hygiene.
- **Provider embeds.** Safe rendering matters more than feature parity across
  video providers. Unsupported URLs fail closed.
