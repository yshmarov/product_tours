# PRD: product_tours

> Status: **shipped as v0.1.1** on 2026-08-04. Audited against the implementation
> on 2026-08-04.

## Product in one sentence

`product_tours` is a self-hosted Rails engine for publishing in-app tutorials,
opening them from host-owned UI, and linking them into lightweight Next/Back
walkthroughs.

## The boundary

The gem owns:

- tutorial persistence and admin CRUD
- draft/published lifecycle
- locale-specific tutorial records and translation creation
- safe video URL resolution, uploads, previews, and embed CSP sources
- a self-contained modal with linked-tutorial Back history
- small lifecycle notifications

The host app owns:

- where triggers appear
- when a trigger is activated
- Help/resource-center navigation
- user/account/tenant identity
- analytics persistence and reporting
- downstream integrations

This boundary is the product. It keeps the gem useful without turning it into an
engagement platform.

## Core decision: tutorials can link; tours are not a model

The code-level unit is `ProductTours::Post`. Admin and visitor UI call it a
**tutorial** or **product tour**.

A Post may point to one other Post in the same locale through
`action_post_key`. The widget opens that target in place and keeps an in-memory
Back stack for the current modal session.

There is no `Course`, `Tour`, `Step`, sequence, ordering, or progress model.
That means:

- every tutorial remains directly invokable by key
- opening a tutorial directly never invents a Back destination
- editors can reuse the same tutorial from several entry points
- navigation state disappears when the modal closes
- there is no persisted completion state to migrate or reconcile

## Users and jobs

### Rails developer

- Install the engine in minutes.
- Place a stable `data-product-tour` key in a view.
- Protect the dashboard using the app's existing authentication.
- Subscribe to lifecycle events using the app's existing analytics stack.
- Avoid another frontend build, third-party script, and vendor account.

### Content admin

- Create a tutorial without deploying.
- Paste a video and see it immediately.
- Choose exactly what the primary button does.
- Link tutorials into a walkthrough without learning a sequence builder.
- Publish/unpublish explicitly.
- Add and manage translations from the tutorial page.

### Visitor

- Open relevant help from the page where it is needed.
- Watch/read the tutorial without leaving the app.
- Move Next/Back through a linked walkthrough.
- Close at any time and return focus to the trigger.
- Never see a server error because a content key is missing or draft.

## Shipped surface

| Area | v0.1.0 behavior |
| --- | --- |
| Install | Generator adds initializer, migration, route mount, instructions, and development demo data |
| Trigger | Any element with `data-product-tour="key"` |
| Widget | Same-origin plain JS, centered desktop modal, full-screen mobile modal |
| Content | Required title; optional Action Text description and optional video |
| Action | Finish/close, open a URL, or continue to another tutorial |
| Status | `draft` or `published` |
| Admin | Published-first sidebar, draft tab, key search/clear, preview, edit, publish, unpublish, delete |
| Locales | Default-locale canonical list; translations created from each tutorial |
| Video URLs | YouTube, Vimeo, Loom, Tella, Voomly, direct MP4/WebM |
| Uploads | Optional Active Storage video attachment |
| Metadata | Safe resolver metadata for every provider; oEmbed title/thumbnail for YouTube, Vimeo, Loom |
| Events | `viewed`, `dismissed`, `completed`, plus unresolved-trigger reporting |
| i18n | 26 locale files with parity tests and RTL support |
| Compatibility | Ruby 3.2–3.4; Rails 7.1, 7.2, 8.0, 8.1 |

## Public integration contract

### Install

```ruby
gem "product_tours"
```

```bash
bin/rails generate product_tours:install
bin/rails db:migrate
```

The route macro mounts the engine and synchronizes `config.mount_path`:

```ruby
mount_product_tours at: "/product_tours"
```

### Render and trigger

```erb
<%= product_tours_tag %>
<button data-product-tour="billing_setup">Watch setup guide</button>
```

`product_tours_tag` emits:

- JSON runtime configuration in `type="application/json"`
- one same-origin, fingerprinted, deferred widget script
- the request's CSP nonce when Rails supplies one

There is no public JavaScript SDK or server-side prompt API. The data attribute
is the complete invocation contract.

### Configuration

`ProductTours::Configuration` exposes only:

| Option | Default |
| --- | --- |
| `enabled` | `true` for every request |
| `authorize_admin` | development environment only |
| `admin_layout` | `product_tours/application` |
| `mount_path` | `/product_tours` |
| `storage_service` | app Active Storage default |

Request-dependent gates receive the raw request.

There is deliberately no `current_user`, `user_label`, `tenant`, `locale`,
`rate_limit`, or `raise_on_unresolved_trigger` setting. Locale follows Rails;
identity belongs in host subscribers; public endpoints are read/signal only;
environment-specific error behavior is fixed and safe.

## Data model

`ProductTours::Post` is stored in `product_tours_posts`:

| Field | Contract |
| --- | --- |
| `key` | Required; lowercase letters/numbers separated by `.`, `_`, or `-` |
| `locale` | Required; defaults to `I18n.default_locale` |
| `status` | `draft` or `published`; defaults to draft |
| `title` | Required |
| `video_url` | Optional supported HTTPS provider/direct-video URL |
| `video_metadata` | Resolver/oEmbed output as JSON |
| `action_label` | Optional; widget supplies Done/Next when blank |
| `action_url` | Optional relative path or HTTP(S) URL |
| `action_post_key` | Optional existing same-locale Post key |

Database constraints/indexes:

- unique `[locale, key]`
- indexes on `locale` and `status`

Optional framework-backed content:

- `has_rich_text :description` when Action Text and its table exist
- `has_one_attached :video` when Active Storage and its tables exist

A primary action may have one destination: URL, linked Post, or neither
(finish/close). Self-links, missing links, cross-locale links, unsafe URLs, and
unsupported videos are invalid.

## Resolution and locale behavior

For a trigger key, the public endpoint:

1. checks `ProductTours.enabled?(request)`
2. validates the key format
3. looks for the requested/current `I18n.locale`
4. falls back to `I18n.default_locale` only when no current-locale record exists
5. opens only the selected record when it is published

An existing draft translation blocks default-locale fallback. This prevents a
partially translated audience from unexpectedly seeing the default-language
tutorial.

Admin behavior:

- Sidebar and New product tour use only `I18n.default_locale`.
- A tutorial detail lists all records sharing its key.
- Add translation duplicates the default-locale/source content into a draft.
- A linked action is copied only when the target key exists in the new locale.
- Default-locale content cannot be deleted while translations still exist.

## Linked navigation

When `action_post_key` is present:

- the action label defaults to Next
- the public widget resolves the target in the current tutorial's locale
- the current Post is pushed onto the in-memory history stack
- the modal content is replaced without a page load
- Back pops and renders the previous Post
- repeated/cyclic navigation is refused client-side
- missing/draft targets use normal unresolved-trigger handling

Lifecycle remains per tutorial. Linked navigation does not create sequence ids,
step numbers, progress percentages, or completion rows.

## Video contract

### Resolver

Only HTTPS URLs without userinfo are considered. Supported hosts and paths are
explicit allowlists:

- YouTube -> `youtube-nocookie.com/embed/<id>`
- Vimeo -> `player.vimeo.com/video/<id>` with privacy hash preservation
- Loom -> `loom.com/embed/<id>`
- Tella -> `tella.tv/video/<id>/embed`
- Voomly -> `embed.voomly.com/embed/assets/embed.html`
- any HTTPS host -> only paths ending in `.mp4` or `.webm`

Unsupported schemes, hosts, paths, and provider lookalikes resolve to nothing.

### Metadata and preview

- Pasted URLs resolve after a short dashboard debounce.
- YouTube, Vimeo, and Loom use provider oEmbed endpoints with short timeouts.
- Failed metadata fetches keep resolver metadata and never block saving.
- Direct videos seek to an early frame for an immediate preview.
- Uploaded videos render in a native `<video>` through a gated engine route.

### CSP

When the host has a Rails Content Security Policy, the engine preserves existing
`frame-src`/`default-src` values and adds only the supported iframe origins. It
removes `'none'` when a real provider must be allowed.

Custom direct-video origins remain the host's `media-src` responsibility.

## Dashboard contract

Mounted at the configured engine path. Access always passes
`authorize_admin`.

Index:

- Published tab before Draft
- counts by status in the default locale
- exact-key suggestions plus partial key search
- visible Clear action when filtered
- 50 records per page
- selected Post keeps sidebar filters/page context
- opening a translation from the detail keeps that same context

Form:

- one full-width field per row
- client-side normalization plus server-side key validation
- language shown but never free-form editable
- URL/upload is an explicit source choice
- immediate safe video preview
- finish / linked tutorial / URL is an explicit action choice
- same-locale next-tutorial select includes drafts for preparation

Detail:

- visitor-like content preview
- key, language, status, media, and action data together
- Edit, Publish/Move to drafts, Delete beside the data they mutate
- translations and Add another language below

The dashboard has its own light/dark responsive CSS and same-origin fingerprinted
JS. It does not require host CSS, Tailwind, Stimulus, or a bundler.

## Lifecycle notifications

The gem creates no analytics table and no cookie.

Signals:

| Notification | Emitted when |
| --- | --- |
| `product_tours.viewed` | Modal is inserted, visible, and focused |
| `product_tours.dismissed` | Modal closes before completion |
| `product_tours.completed` | Primary action is used |

Payload keys:

```ruby
post_id
key
locale
page_url # query string and fragment removed
source
```

Video playback does not mean completion. The host may subscribe with Ahoy or
another analytics system and attach its own identity/account context.

## Unresolved triggers

Reasons: `invalid_key`, `missing`, `unpublished`, `disabled`.

Visitor behavior is always fail-closed: no modal and no lifecycle signal.

- Development/test raises `ProductTours::UnresolvedTriggerError`.
- Production reports a handled error through `Rails.error`, logs when that API
  is unavailable, instruments `product_tours.unresolved_trigger`, and returns a
  JSON 404 to the widget.

Payload: `key`, `locale`, `reason`, and query-free `page_url`.

## Accessibility and responsive behavior

- `role="dialog"` with an accessible localized name
- labelled close control
- focus moves into the modal and returns to the trigger
- focus trap while open
- Escape dismisses
- video/control elements remain keyboard reachable
- full-screen layout at <=480px
- safe-area padding and `visualViewport` adjustment
- RTL locale support
- no animation required for state comprehension

## Security and privacy

- Dashboard authorization is server-side on every request.
- Public resolution returns only enabled, published content.
- Action URLs reject script/data schemes and protocol-relative URLs.
- Provider URLs fail closed through a host/path allowlist.
- Uploaded media requires admin access or enabled + published content.
- JSON config escapes closing-script sequences.
- Scripts are same-origin, fingerprinted, deferred, and nonce-aware.
- Page URLs lose query strings/fragments before instrumentation.
- No user id, account id, tenant, user agent, tracking cookie, or persistent
  progress is owned by the gem.

## Demo contract

Development migration seeding creates the default locale only. The explicit
`product_tours:seed_demo` task creates English, French, and Bulgarian records.

The set is idempotent and includes:

- a linked walkthrough start, provider comparison, all six video examples, and
  finish
- individually invokable provider tutorials
- direct MP4
- relative URL action
- draft tutorial
- button for an intentionally missing key

The installer and seed task print the exact ERB trigger block.

## Non-goals

- DOM-anchored tooltips or selector recording
- persisted Tour/Course/Step models
- automatic ordering or progress
- checklists
- page rules or automatic scheduling
- gem-owned launcher, Help menu, or resource center
- analytics/event persistence or dashboards
- user/account/tenant tracking
- experiments, segmentation, or feature flags
- Segment, Amplitude, Mixpanel, Slack, or other direct integrations
- browser recording or media creation
- AI authoring
- mobile SDKs
- testimonials, NPS, feedback, bug reports, or support chat

Sibling gems own those adjacent jobs where appropriate: `testimonials`,
`ideasbugs`, `livechat`, and `i18n_proofreading`.

## Acceptance status

v0.1.1 is accepted when all of the following remain true:

- fresh generated install boots on Rails 7.1+
- demo migration/task behavior is idempotent
- admin is development-only by default
- public triggers open only published current/default-locale content
- linked tutorials provide in-modal Next/Back without a grouping model
- every supported video provider resolves safely
- Action Text and Active Storage remain optional
- CSP host rules are preserved while provider frame origins are added
- no gem tracking table, identity setting, tenant setting, or cookie exists
- locale files have identical keys
- tests cover generators, model validation, resolver safety, dashboard CRUD,
  translations, widget resolution, lifecycle events, Turbo, and CSP
- CI passes Ruby 3.2/3.3/3.4 across Rails 7.1/7.2/8.0/8.1

Changes that violate the boundary above require an explicit product decision,
not incidental implementation drift.
