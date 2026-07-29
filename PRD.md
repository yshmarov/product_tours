# PRD: product_tours

> Status: draft, revised 2026-07-29 after reviewing `livechat`,
> `testimonials`, `i18n_proofreading`, `ideasbugs`, and the current product
> adoption market.

## Summary

`product_tours` is a Rails engine for self-hosted product adoption: product
tours, contextual guides, onboarding checklists, and an optional resource
center, all managed inside the host app and stored in the host database.

It should be a real Rails-native alternative to Appcues, Userflow, Chameleon,
and Pendo for teams that want in-app guidance without a third-party script,
external user database, MAU pricing, or a separate product-adoption platform.

The first public release must be narrow enough to ship, but not so narrow that
it feels like a video embed helper. The durable product is:

```ruby
gem "product_tours"
```

```erb
<%# app/views/layouts/application.html.erb, before </body> %>
<%= product_tours_tag %>

<%# Any page where the app knows the right context %>
<%= product_tour_button(:billing_setup) %>
<%= product_tour_embed(:onboarding_video) %>
<%= product_tour_anchor(:billing_plan, tag: :section) do %>
  ...
<% end %>
```

Product promise:

> Product tours for Rails. Build in-app onboarding, feature guides, and
> checklists from your own app. Your UI, your database, no third-party widget.

## Market Scan

Hosted product-adoption tools converge on the same surface area:

- Appcues offers flows, checklists, embeds, NPS/surveys, segmentation, and
  reporting. Its public pricing is MAU and published-experience based.
  See [Appcues Experiences](https://www.appcues.com/experiences) and
  [Appcues Pricing](https://www.appcues.com/pricing).
- Userflow positions around product tours, checklists, surveys, banners,
  resource centers, targeting, triggers, analytics, and AI assistance. Its
  current pricing starts at $500/month for Adoption Studio at 1K MAUs.
  See [Userflow](https://www.userflow.com/) and
  [Userflow Pricing](https://www.userflow.com/pricing).
- Chameleon supports tours, tooltips, embeddables, microsurveys, launchers,
  targeting, scheduling, recurrence, localization, A/B testing, goals, and
  integrations. Its current Pro plan starts at $750/month.
  See [Chameleon Tours](https://www.chameleon.io/tours) and
  [Chameleon Plans](https://www.chameleon.io/plans).
- Pendo's Resource Center is an always-available in-app menu containing guide
  lists, onboarding checklists, announcements, custom modules, and segmented
  content. See
  [Pendo Resource Center](https://support.pendo.io/hc/en-us/articles/360031866712-Overview-of-the-Resource-Center).
- Open-source JS libraries such as [Driver.js](https://driverjs.com/) and
  [Intro.js](https://introjs.com/) prove that lightweight, dependency-free
  step-through overlays can win broad adoption. They are not Rails products:
  they do not provide dashboard content management, Rails auth, tenant scoping,
  event persistence, install generators, or a database-backed admin workflow.

Conclusion: to be a SaaS replacement, `product_tours` must eventually cover
tours, checklists, contextual launchers, resource-center style self-service,
targeting, recurrence, localization, and analytics. To stay gem-sized, it
should replace brittle no-code DOM selection with Rails-native anchors and
host-defined context.

## Positioning

**Self-hosted product adoption for Rails.** Developers place stable hooks in
the app. Product/support/admin users manage the content from a mounted
dashboard. End-user behavior is tracked in the same database as the product.

This is intentionally different from generic SaaS tools:

- The host app already knows the user, account, plan, role, feature flags, and
  lifecycle state. The gem should use request lambdas and server-side helpers
  instead of syncing a shadow customer database into another vendor.
- The host app already knows where important workflows live. The gem should use
  explicit Rails helpers and `data-product-tour-anchor` markers instead of
  pretending a visual DOM picker will survive every deploy.
- The host app already has auth, tenancy, mailers, jobs, CSP, and I18n. The gem
  should fit those systems rather than replacing them.

Tagline:

> `product_tours` - product tours, onboarding checklists, and in-app guidance
> for Rails. Self-hosted, no third-party script, no MAU tax.

## Goals

- Install in under 5 minutes on a fresh Rails app.
- Work with Rails 7.1+ and Ruby 3.2+.
- Ship as a mountable Rails engine with isolated namespace
  `ProductTours`.
- Store guides, steps, checklists, progress, and events in host-app tables.
- Let developers place tours by stable keys and anchors.
- Let admins update guide content, ordering, status, CTA, and media without a
  deploy.
- Support signed-in and anonymous visitors.
- Support multi-tenant apps through an opaque tenant key.
- Support eligibility via host-provided segments/context, not user-data sync.
- Work with plain Rails views, Turbo Drive, and strict nonce-based CSP.
- Avoid Tailwind, Stimulus, importmap, node, npm, CDN, or host asset-pipeline
  assumptions.
- Provide enough analytics to answer: who saw this, who dismissed it, where did
  they drop off, and which guides helped users complete onboarding.

## Non-Goals

Absolute non-goals for v1:

- No external hosted service.
- No third-party tracking script.
- No syncing users/accounts into a vendor database.
- No browser extension visual builder.
- No AI authoring, summarization, transcript generation, or chatbot.
- No mobile SDKs.
- No enterprise workflow suite: roles, approvals, SAML, experiments, contracts,
  or cross-workspace governance stay out of the gem.

Deferred until there is real demand:

- A/B testing.
- Advanced analytics charts.
- Automated DOM scraping or no-code event capture.
- Browser-based video recording.
- Built-in video hosting.
- Active Storage uploads for tour media.
- Deep integrations with Segment, Amplitude, Mixpanel, HubSpot, Slack, etc.
  Hooks and documented recipes come first.

## Product Principles

- **Rails-native beats no-code.** The winning difference is native Rails
  placement, auth, tenancy, I18n, and persistence.
- **Developer-placed, admin-managed.** Code defines where guidance may appear;
  admins manage content and publishing.
- **Anchors over selectors.** Use stable `data-product-tour-anchor` markers and
  helper-generated targets before arbitrary CSS selectors.
- **Intent beats interruption.** Explicit clicks, checklists, and resource
  center opens are safer defaults than surprise auto-starts.
- **One guide, one outcome.** A tour should guide a user to a single activation
  or adoption milestone.
- **Self-hosted by default.** Content and events stay in the host database.
- **Small frontend, strong backend.** Plain JS for playback and overlays;
  Active Record for content, eligibility, and analytics.
- **No frontend assumptions.** The widget works in any Rails UI stack.
- **Strict CSP is table stakes.** Same-origin scripts, nonce support, no inline
  event handlers.
- **Screenshots sell the gem.** The README must show a polished widget,
  walkthrough, checklist, and dashboard before the gem is announced widely.

## Reference Gem Patterns To Reuse

`product_tours` should follow the same house architecture as the user's shipped
gems:

- `isolate_namespace ProductTours`.
- `ProductTours::Configuration` as a PORO with safe defaults.
- `ProductTours.configure { |config| ... }`.
- Request-dependent lambdas receive the raw request.
- Dashboard access defaults to development only.
- Public/user endpoints are independently gated by `enabled`.
- Loose host references: `author_id`, `visitor_id`, `tenant` are strings, not
  foreign keys to host models.
- Optional model concern loaded through `ActiveSupport.on_load(:active_record)`.
- Widget helper loaded through `ActiveSupport.on_load(:action_view)`.
- Controller helper loaded through `ActiveSupport.on_load(:action_controller)`
  when server-side prompts or completion helpers exist.
- Widget JS and dashboard JS live in `lib/product_tours/*.js`.
- JS is served same-origin by the engine with content fingerprints.
- Helpers emit a JSON config script plus a same-origin `defer` script, matching
  the Turbo/CSP-safe pattern from `livechat`, `testimonials`, and `ideasbugs`.
- Runtime dependency should be Rails only unless a dependency is overwhelmingly
  justified.
- Minitest, not RSpec.
- `test/dummy` app with fixed nonce CSP tests.
- CI matrix across Rails 7.1, 7.2, 8.0, 8.1 and Ruby 3.2, 3.3, 3.4.
- 26 locale files with locale parity tests.
- README structure: badges, one-line positioning, screenshot/GIF, install,
  "What you get", "Why self-host", flow screenshots, configuration table,
  multi-tenancy docs, Turbo/CSP notes, tests.
- Keep-a-Changelog style `CHANGELOG.md`.
- Trusted publishing release workflow on `v*` tags.

## Personas

1. **End user** - signed-in or anonymous user learning a workflow inside the
   host app.
2. **Customer admin** - tenant-side admin completing setup, inviting teammates,
   configuring billing, or discovering advanced features.
3. **Product/support/admin user** - manages guide content, watches drop-off,
   updates onboarding copy, and retires stale tours.
4. **Host developer** - installs the gem, places anchors/triggers, wires auth,
   tenant, segments, and completion events.

## Core Product Surface

### 1. Guide Library

A guide is the base content unit. It can be presented as a modal video, inline
embed, step-through walkthrough, checklist item, announcement, or resource
center entry as the gem grows.

v0.1 must support:

- one-step modal guides
- inline embed guides
- video guides
- multi-step anchored walkthroughs
- CTA links
- viewed, dismissed, completed, and CTA events
- tenant scoping
- basic eligibility by segment

v0.2 should support:

- onboarding checklists
- resource-center launcher
- show-once/show-until-completed behavior
- completion helper API

### 2. Anchored Walkthroughs

The developer places stable anchors:

```erb
<%= product_tour_anchor(:billing_plan, tag: :section) do %>
  <%= render "billing/plan_picker" %>
<% end %>
```

The dashboard lets an admin create steps that target those anchor keys. The
browser widget highlights the anchor and shows the step popover.

Required behavior:

- A missing anchor skips the step by default and records `step_skipped`.
- A tour with no visible steps does not start.
- The popover supports title, body, optional video/media URL, primary CTA, and
  secondary "Skip".
- Progress text is shown for multi-step tours.
- Placement is best-effort: `auto`, `top`, `right`, `bottom`, `left`.
- Keyboard support: Escape dismisses; Enter/Space on controls works; focus is
  trapped while a modal/popover is active.
- Mobile fallback: anchored tours render as a bottom sheet if the target cannot
  be positioned cleanly.

v0.1 should implement the overlay in the gem's own plain JS rather than pulling
Driver.js or Intro.js. If positioning complexity grows, Driver.js is the
preferred candidate because it is MIT licensed, small, dependency-free, and
already covers tours, highlights, hints, progress, hooks, and accessibility.
Intro.js is less attractive for commercial Rails apps because its open-source
license is AGPL with a commercial license for commercial use.

### 3. Video Guides

Video stays important, but it is one guide format, not the whole product.

Supported in v0.1:

- YouTube
- Vimeo
- Loom
- Tella
- direct MP4/WebM URLs

Provider handling:

- Normalize supported provider URLs into embeddable players where practical.
- Use a direct `<video>` player for direct media URLs.
- Record completion only where completion can be detected reliably.
- Fall back to `viewed` and `dismissed` for providers without reliable
  completion events.
- Never require Active Storage for v0.1.

### 4. Checklists

Checklists are needed for SaaS-replacement credibility. They do not have to
ship in v0.1, but the v0.1 schema should not block them.

Expected v0.2 behavior:

- `product_tour_checklist(:onboarding)` helper renders a self-styled checklist.
- A checklist contains ordered items.
- Items can launch a guide, navigate to a URL, or mark complete from a host
  completion event.
- Progress is stored per visitor/user/tenant.
- A checklist hides when all required items are complete, unless configured to
  remain available.

### 5. Resource Center

Expected v0.2/v0.3 behavior:

- `product_tours_resource_center` helper or `show_resource_center` config
  renders an always-available launcher.
- The panel lists eligible guides, checklists, announcements, and external
  links.
- It is segmented by tenant, page, and host-provided segment keys.
- Empty centers render nothing.

### 6. Server-Side Prompts And Completion

The host app knows success moments. Copy the `testimonials` pattern:

```ruby
class BillingController < ApplicationController
  def update
    # ...
    product_tours_complete!(:billing_setup)
    product_tour_prompt!(:invite_team)
    redirect_to billing_path
  end
end
```

Required behavior:

- `product_tour_prompt!(key)` stores a flash-like signal for the next HTML
  render.
- Auto-prompting respects recurrence rules.
- Explicit clicks bypass recurrence rules.
- `product_tours_complete!(key)` records completion for the current
  user/visitor/tenant and creates a `completed` event.

## Installation

```bash
bundle add product_tours
bin/rails generate product_tours:install
bin/rails db:migrate
```

The installer creates:

- initializer
- migration
- engine mount route
- post-install instructions

Default mount path:

```text
/product_tours
```

Layout install:

```erb
<%= product_tours_tag %>
```

Post-install output should say:

- run `rails db:migrate`
- add `<%= product_tours_tag %>` before `</body>`
- manage guides at `/product_tours`
- dashboard is development-only until `config.authorize_admin` is set

## Configuration

Generated initializer:

```ruby
ProductTours.configure do |config|
  config.enabled = ->(_request) { true }
  config.authorize_admin = ->(_request) { Rails.env.development? }
  config.current_user = ->(_request) {}
  config.tenant = ->(_request) {}
  config.author_label = ->(user) { user.try(:name).presence || user.try(:email).presence || user&.to_s }
  config.visitor_label = ->(user) { user.try(:name).presence || user.try(:email).presence || user&.to_s }
  config.segments = ->(_request) { [] }
  config.context = ->(_request) { {} }
  config.mount_path = "/product_tours"
  config.rate_limit = { to: 60, within: 1.minute }
  config.show_resource_center = false
  config.accent_color = nil
  config.on_event = ->(_event) {}
  config.on_complete = ->(_progress) {}
end
```

Configuration requirements:

- `enabled` gates end-user helpers, widget rendering, and public endpoints.
- `authorize_admin` gates the dashboard and defaults to development only.
- `current_user` returns any object responding to `id`, or `nil`.
- `tenant` returns an opaque string key, or `nil` for a global installation.
- `author_label` stores a display label for admin-side event attribution.
- `visitor_label` stores a label for end-user/user analytics.
- `segments` returns an array of strings such as `["admin", "trial",
  "billing_incomplete"]`.
- `context` returns a small JSON-safe hash available for future advanced rules
  and event metadata.
- `mount_path` must match the engine route.
- `rate_limit` uses Rails 7.2+ rate limiting and no-ops on Rails 7.1.
- `accent_color` restyles widget controls with automatic contrast.
- `on_event` runs after event creation and should stay fast.
- `on_complete` runs after a progress row becomes completed and should stay
  fast.

## Data Model

Use table names with the engine prefix.

### ProductTours::Tour

Fields:

- `key`
- `status`
- `kind`
- `title`
- `description`
- `video_url`
- `thumbnail_url`
- `cta_label`
- `cta_url`
- `segments`
- `page_rules`
- `trigger`
- `recurrence`
- `priority`
- `tenant`
- `position`
- `metadata`

Enums:

```ruby
enum :status, %w[draft published archived].index_by(&:itself)
enum :kind, %w[modal video embed walkthrough checklist resource].index_by(&:itself)
```

Rules:

- `key` is stable and developer-facing.
- `published` tours are visible to eligible end users.
- `tenant` is an opaque string; `nil` means global.
- `segments`, `page_rules`, `recurrence`, and `metadata` are JSON columns when
  supported by the database, else text serialized by Rails.
- v0.1 supports `modal`, `video`, `embed`, and `walkthrough`.
- `checklist` and `resource` are schema-reserved for v0.2+.
- Enums are string-backed.

Indexes:

- unique index on `tenant, key`
- index on `status`
- index on `kind`
- index on `tenant, status`
- index on `priority`

### ProductTours::Step

Fields:

- `tour_id`
- `key`
- `position`
- `anchor_key`
- `placement`
- `title`
- `body`
- `video_url`
- `cta_label`
- `cta_url`
- `completion_key`
- `metadata`

Rules:

- Steps belong to a tour.
- `key` is stable within the tour.
- `anchor_key` points to a `product_tour_anchor` marker.
- `completion_key` is optional and lets checklist items or tour steps complete
  from host-side events.
- A video/modal guide can be represented as a tour with one step.

Indexes:

- unique index on `tour_id, key`
- index on `tour_id, position`
- index on `anchor_key`
- index on `completion_key`

### ProductTours::Progress

Fields:

- `tour_id`
- `tenant`
- `author_id`
- `visitor_token`
- `status`
- `started_at`
- `completed_at`
- `dismissed_at`
- `last_step_key`
- `metadata`

Enums:

```ruby
enum :status, %w[not_started started dismissed completed].index_by(&:itself)
```

Rules:

- `author_id` is a string, not a foreign key.
- `visitor_token` supports anonymous tracking.
- A signed-in user's progress keys by `author_id`; anonymous progress keys by
  `visitor_token`.
- Progress supports show-once, show-until-completed, and checklist state.

Indexes:

- index on `tour_id, status`
- index on `tenant, author_id, tour_id`
- index on `tenant, visitor_token, tour_id`
- index on `completed_at`

### ProductTours::Event

Fields:

- `tour_id`
- `step_id`
- `action`
- `tenant`
- `author_id`
- `author_label`
- `visitor_token`
- `page_url`
- `locale`
- `user_agent`
- `metadata`

Enums:

```ruby
enum :action, %w[
  shown
  started
  viewed
  step_viewed
  step_skipped
  dismissed
  completed
  cta_clicked
].index_by(&:itself)
```

Rules:

- `author_id` is stored as a string, not a foreign key.
- `visitor_token` supports guest/userless tracking.
- `page_url` strips query strings by default.
- `metadata` stores non-sensitive JSON only.
- Enums are string-backed.

Indexes:

- index on `tour_id, action`
- index on `step_id, action`
- index on `tenant`
- index on `author_id`
- index on `visitor_token`
- index on `created_at`

## Multi-Tenancy

The host app may scope tours by providing a tenant key:

```ruby
config.tenant = ->(_request) { Current.organization&.to_gid&.to_s }
```

Behavior:

- Dashboard reads and writes tours for the current tenant.
- Global tours have `tenant: nil`.
- Tenant-specific tours can override global tours with the same key.
- End-user helpers resolve the tenant-specific tour first, then fall back to a
  global tour.
- Progress and events are stamped with the current tenant.

Optional model helper:

```ruby
class Organization < ApplicationRecord
  has_product_tours
end
```

The helper is sugar over the opaque tenant key, matching the `has_feedback` and
`has_testimonials` pattern.

## Eligibility, Targeting, And Recurrence

v0.1 should include simple, Rails-native targeting:

- tenant match
- status published
- segment intersection
- optional page path match
- recurrence rules

Tour fields:

```ruby
segments: ["admin", "trial"]
page_rules: { paths: ["/billing*", "/settings/billing"] }
recurrence: { mode: "until_completed", cooldown_days: 7, max_shows: 3 }
trigger: "manual"
```

Trigger modes:

- `manual` - helper button/link, JS API, or resource center only.
- `auto` - allowed to auto-open when eligible and recurrence allows it.
- `completion` - used as a checklist/resource item, not auto-opened directly.

Rules:

- Empty `segments` means all segments.
- Empty `page_rules` means any page where the helper/tag is rendered.
- Auto-start should be conservative. Default created tours should be manual.
- Explicit user action bypasses cooldown but not `enabled`, status, tenant, or
  segment eligibility.

## View Helpers And JS API

Core helpers:

```erb
<%= product_tours_tag %>
<%= product_tour_button(:billing_setup) %>
<%= product_tour_link(:billing_setup, "Watch setup guide") %>
<%= product_tour_embed(:billing_setup) %>
<%= product_tour_anchor(:billing_plan, tag: :section) do %>
  ...
<% end %>
```

Required behavior:

- Render nothing if the tour is missing, unpublished, disabled, or ineligible.
- `product_tours_tag` emits the JSON config and same-origin widget script.
- Button/link helpers open the guide without a full page reload.
- Embed helper renders an inline card/player.
- Anchor helper renders the requested HTML tag with a stable
  `data-product-tour-anchor`.
- Opening a guide records `started` or `viewed`.
- Each visible step records `step_viewed`.
- Closing before completion records `dismissed`.
- CTA clicks record `cta_clicked`.
- Finishing all required steps records `completed`.

JS API:

```js
window.ProductTours.open("billing_setup")
window.ProductTours.complete("billing_setup")
window.ProductTours.refresh()
```

The JS API is useful for host UI triggers, Turbo visits, and custom onboarding
menus.

## Dashboard

Mounted at `/product_tours` by default.

Pages:

- guide index
- new guide
- edit guide
- show guide
- step editor
- event summary
- progress/users summary

Index filters:

- status
- kind
- key
- tenant
- segment
- recently viewed
- low completion

Dashboard requirements:

- Development-only access by default.
- Host-configured admin gate for production use.
- No dependency on host CSS framework.
- Self-contained light/dark theme with CSS custom properties.
- No inline event handlers.
- Same-origin `dashboard.js` with a fingerprinted URL.
- Preview video URLs on show/edit pages.
- Preview walkthrough steps against known anchors where possible.
- Show event counts and completion rate for each guide.
- Show stale guide warning if no events have arrived recently.

## I18n

The gem UI uses keys under:

```yaml
product_tours:
```

Requirements:

- Ship the same 26 locales as `livechat`, `testimonials`,
  `i18n_proofreading`, and `ideasbugs`.
- Every widget/dashboard string goes through `I18n.t` with an English default.
- RTL language detection mirrors the existing widget pattern.
- v0.1 stores guide content as plain strings.
- Localized guide fields are v0.3 unless a first real integration requires
  them earlier.

## Privacy And Security

- Dashboard access must be explicitly gated outside development.
- End-user event/write endpoints should be rate-limited.
- Do not store full request params.
- Strip query strings from `page_url` by default.
- Store host user references as loose strings, not foreign keys.
- Do not expose raw Active Storage blob URLs if uploads are added later.
- Use same-origin scripts with request nonces.
- No inline event handlers.
- Escape `</` in JSON config script tags.
- Event metadata must be documented as non-sensitive.
- Provide `ProductTours::Event.prune(older_than:)` or a documented retention
  recipe before v1.0.

## Accessibility

v0.1 requirements:

- Buttons have labels and keyboard behavior.
- Modal/player uses `role="dialog"` and focus trap.
- Escape dismisses modal/popover.
- Popover controls are reachable by keyboard.
- ARIA labels for next, previous, close, dismiss, and progress.
- Respect `prefers-reduced-motion`.
- Do not trap users in a walkthrough with no visible exit.

## Acceptance Criteria

- Fresh install works in a Rails 7.1+ dummy app.
- The generated initializer boots with safe defaults.
- The dashboard is inaccessible outside development unless `authorize_admin`
  allows access.
- `product_tours_tag` serves same-origin JS with a content fingerprint.
- The widget works with Turbo Drive.
- The widget works under nonce-based CSP.
- `product_tour_button(:key)` renders only for a published eligible tour.
- Clicking a product tour button opens a guide without a full page reload.
- `product_tour_embed(:key)` renders an inline player/card.
- `product_tour_anchor(:key)` emits a stable anchor marker.
- A multi-step walkthrough can highlight two anchors and complete.
- Missing anchors are skipped without breaking the page.
- Opening a guide records `started` or `viewed`.
- Viewing a step records `step_viewed`.
- Closing an unfinished guide records `dismissed`.
- CTA clicks are recorded when a CTA is configured.
- Completing all required steps records `completed` and updates progress.
- Tenant-specific tours override global tours with the same key.
- Segment eligibility works from `config.segments`.
- Tests cover helpers, dashboard authorization, guide lifecycle, step
  ordering, event recording, progress, tenant scoping, segment eligibility,
  Turbo, and CSP.

## README Positioning

Hero:

> Product tours for Rails.

Subhead:

> Add guided onboarding, contextual help, video walkthroughs, and checklists to
> your Rails app. Your app, your database, no third-party widget.

What you get:

|                  |                                                                     |
| ---------------- | ------------------------------------------------------------------- |
| **Tours**        | Anchored multi-step walkthroughs with progress and completion events |
| **Guides**       | Modal and inline video guides for contextual help                    |
| **Checklists**   | Setup tasks and adoption milestones, v0.2                            |
| **Dashboard**    | Draft/publish/archive, step editor, usage and completion stats       |
| **Targeting**    | Tenant, page, and host-defined segments                              |
| **Storage**      | Ordinary Active Record rows in your app database                     |
| **Deps**         | None. Plain JS, no Tailwind, no Stimulus, no importmap, no build step |
| **Auth**         | Lambdas over the raw request: Devise, Rails 8 auth, anything         |
| **i18n**         | 26 languages, RTL included                                           |
| **Turbo/CSP**    | Turbo Drive and strict nonce-based CSP out of the box                |

Comparison:

|                         | `product_tours`       | Hardcoded help | Product-tour SaaS |
| ----------------------- | --------------------- | -------------- | ----------------- |
| Cost                    | Free, MIT             | Free           | Monthly/MAU based |
| Where guide data lives  | Your database         | Code           | Vendor database   |
| Third-party script      | No                    | No             | Yes               |
| Rails user attribution  | Server-side session   | Manual         | Synced/user attrs  |
| Tenant scoping          | Built in              | Manual         | Often paid         |
| Admin-managed content   | Yes                   | No             | Yes               |
| Anchored walkthroughs   | Yes                   | Custom JS      | Yes               |
| Checklists              | v0.2                  | Custom code    | Yes               |
| Resource center         | v0.2/v0.3             | Custom code    | Yes               |
| Analytics/events        | In your DB            | Manual         | Vendor dashboard   |
| Branding                | Your app              | Your app       | Often plan-gated   |
| Data ownership          | Host-owned            | Host-owned     | Vendor-owned       |

README must include:

- install commands
- first tour in under 5 minutes
- a minimal anchor walkthrough example
- a video-guide example
- a checklist example once v0.2 ships
- configuration table
- Devise and Rails 8 auth examples
- multi-tenancy example
- Turbo/CSP explanation
- screenshots or GIFs of the widget, walkthrough, checklist, and dashboard
- explicit "why not Appcues/Userflow/Chameleon/Pendo" comparison
- explicit "why not Driver.js/Intro.js" comparison

## Milestones

### v0.1 - Rails-Native Tour Foundation

- engine skeleton
- install generator
- initializer
- migrations for tours, steps, progress, events
- `product_tours_tag`
- `product_tour_button`
- `product_tour_link`
- `product_tour_embed`
- `product_tour_anchor`
- modal/video guides
- anchored multi-step walkthroughs
- manual and conservative auto triggers
- event recording
- progress recording
- tenant scoping
- segment eligibility
- dashboard CRUD
- event/progress summary
- Turbo/CSP-safe JS delivery
- 26 locales
- Minitest coverage and CI matrix
- README screenshots/GIFs

### v0.2 - Checklists And Resource Center

- `product_tour_checklist`
- checklist item model behavior using existing steps
- completion helper API
- resource center launcher/panel
- show-once and show-until-completed helpers
- empty-state suppression
- import/export seed YAML for host apps

### v0.3 - Localization And Media Polish

- localized guide fields
- Active Storage uploads for media
- poster image handling
- captions/transcript field
- public read API for eligible resource-center content
- better mobile anchored-tour behavior

### v0.4 - Analytics And Hooks

- funnel/drop-off dashboard
- goal events
- per-step completion rates
- retention/pruning helper
- webhook-style hooks documented for Slack, email, analytics, and CRM
- optional CSV export

### v1.0 - Public Launch Quality

- stable public API
- upgrade guide
- demo app
- polished README
- screenshots and short demo video
- production adoption case study from one real Rails SaaS
- issues labeled for contributors
- "good first issue" backlog

## 5K-Star Strategy

The gem will not get 5K GitHub stars by being a slightly nicer embed helper.
The launch story has to be sharper:

- Build the first Rails-native Appcues/Userflow/Chameleon/Pendo alternative.
- Make the install genuinely copy-paste simple.
- Show a working, polished product in the README's first viewport.
- Emphasize no third-party script, no MAU tax, no vendor database, no lock-in.
- Ship real screenshots, GIFs, and a demo app before broad launch.
- Publish comparison pages/sections for Appcues, Userflow, Chameleon, Pendo,
  Driver.js, and Intro.js.
- Keep the runtime boring: Rails, Active Record, plain JS.
- Make contributor entry easy: documented architecture, small issues, clear
  tests, stable local setup.

## Risks And Open Questions

- **Scope creep.** SaaS competitors are large platforms. The gem must win by
  being the Rails-native 80% solution, not by copying every enterprise feature.
- **Overlay positioning complexity.** Anchored tours can get hard around
  scrolling containers, transforms, fixed headers, and mobile. Keep v0.1
  conservative and be willing to adopt Driver.js later if the in-house code
  grows too complex.
- **Auto-start annoyance.** Default to manual triggers. Require deliberate
  recurrence settings for auto prompts.
- **Stale content.** Dashboard should show last-viewed/last-completed signals
  so old tours are easy to retire.
- **Sensitive URLs.** Strip query strings by default and document event
  metadata hygiene.
- **Name risk.** `product_tours` is descriptive and safer than using a vendor
  name. Keep branding generic.

## Success Criteria

- Fresh Rails app to first working anchored tour in under 5 minutes.
- A developer can add a two-step walkthrough with two helpers and dashboard
  content only.
- A non-developer admin can update guide copy/video/CTA without a deploy.
- A multi-tenant Rails SaaS can scope guides per tenant with one lambda.
- A strict CSP host has zero console violations.
- The README makes the product visually obvious within the first screen.
- The gem can honestly say: "Use this when Appcues/Userflow/Chameleon/Pendo is
  too expensive, too external, or too much platform for a Rails app."
