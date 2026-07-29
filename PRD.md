# Product Tours PRD

## Summary

Product Tours is a Rails engine for self-hosted in-app guidance. The first release focuses on video-led product tours: short, admin-managed guides that developers place inside application workflows.

The gem should provide:

```ruby
gem "product_tours"
```

```erb
<%= product_tour_button(:billing_setup) %>
<%= product_tour_embed(:onboarding) %>
```

Product promise:

> Open-source product tours and in-app guides for Rails. Manage videos from a dashboard, show them in your app, and track what users watched.

## Goals

- Let Rails apps add contextual product help without a third-party script.
- Let developers place guides by stable keys.
- Let admins update guide content without a deploy.
- Store tour content, configuration, and usage events in the host app database.
- Support multi-tenant apps through host-provided tenant resolution.
- Work with plain Rails views, Turbo Drive, and strict CSP.

## Non-Goals

- No no-code product-tour builder in v0.1.
- No multi-step walkthroughs, hotspots, or DOM targeting in v0.1.
- No LMS, course progress, quizzes, or training certification.
- No browser-based video recording.
- No built-in video hosting in v0.1.
- No AI transcript generation.
- No dependency on Tailwind, Stimulus, importmap, or any host CSS framework.

## Target Users

Primary users:

- Rails SaaS teams adding lightweight in-app onboarding.
- B2B applications with workflows that need short explanation.
- Internal tools where repeated support questions can be answered in context.
- Apps that do not want hosted product-tour scripts or external adoption platforms.

End users:

- Signed-in app users learning a workflow.
- Tenant admins completing setup.
- Staff or operators performing infrequent tasks.

Admin users:

- Founder/operator.
- Support lead.
- Customer success lead.
- Product manager.
- Training or enablement owner.

## Product Principles

- **Developer-placed, admin-managed.** Code decides where tours appear; the dashboard manages content.
- **One guide, one moment.** Each tour should answer one product question in context.
- **Self-hosted by default.** Content and events live in the host application database.
- **Video-first.** v0.1 ships video tours only, while the data model leaves room for future guide types.
- **URL-first.** Hosted video URLs ship before Active Storage uploads.
- **Loose host coupling.** Current user, tenant, and authorization are resolved through request lambdas.
- **No frontend assumptions.** Plain JavaScript, no framework dependency, no build step.

## Installation

```bash
bundle add product_tours
bin/rails generate product_tours:install
bin/rails db:migrate
```

The installer should create:

- engine mount route
- initializer
- migration

Default mount path:

```text
/product_tours
```

## Configuration

Generated initializer:

```ruby
ProductTours.configure do |config|
  config.enabled = ->(_request) { true }
  config.authorize_admin = ->(_request) { Rails.env.development? }
  config.current_user = ->(_request) {}
  config.tenant = ->(_request) {}
  config.author_label = ->(user) { user.respond_to?(:email) ? user.email : user&.to_s }
  config.mount_path = "/product_tours"
  config.rate_limit = { to: 60, within: 1.minute }
  config.on_event = ->(_event) {}
end
```

Configuration requirements:

- `enabled` controls whether tours render and event endpoints accept writes.
- `authorize_admin` gates the dashboard and defaults to development only.
- `current_user` returns any object responding to `id`, or `nil`.
- `tenant` returns an opaque string key, or `nil` for a global installation.
- `author_label` stores a display label for event attribution.
- `mount_path` must match the engine route.
- `on_event` runs after event creation and should stay fast.

## Data Model

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
- `tenant`
- `position`
- `metadata`

Enums:

```ruby
enum :status, %w[draft published archived].index_by(&:itself)
enum :kind, %w[video].index_by(&:itself)
```

Rules:

- `key` is stable and developer-facing.
- `published` tours are visible to end users.
- `tenant` is an opaque string; `nil` means global.
- v0.1 only supports `kind: "video"`.
- Enums are string-backed.

Indexes:

- unique index on `tenant, key`
- index on `status`
- index on `kind`

### ProductTours::Event

Fields:

- `tour_id`
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
enum :action, %w[viewed dismissed completed cta_clicked].index_by(&:itself)
```

Rules:

- `author_id` is stored as a string, not a foreign key.
- `visitor_token` supports guest/userless tracking where needed.
- `page_url` should avoid storing sensitive query strings.
- Enums are string-backed.

Indexes:

- index on `tour_id, action`
- index on `tenant`
- index on `created_at`

## Multi-Tenancy

The host app may scope tours by providing a tenant key:

```ruby
config.tenant = ->(request) { Current.organization&.to_gid&.to_s }
```

Behavior:

- Dashboard reads and writes tours for the current tenant.
- Global tours have `tenant: nil`.
- Tenant-specific tours can override global tours with the same key.
- End-user helpers should resolve the tenant-specific tour first, then fall back to a global tour.

Optional model helper:

```ruby
class Organization < ApplicationRecord
  has_product_tours
end
```

The helper is sugar over the opaque tenant key, not a hard dependency on host models.

## View Helpers

Core helpers:

```erb
<%= product_tour_button(:billing_setup) %>
<%= product_tour_link(:billing_setup, "Watch setup guide") %>
<%= product_tour_embed(:billing_setup) %>
```

Required behavior:

- Render nothing if the tour is missing, unpublished, disabled, or not available for the current tenant.
- Open a modal/player for button and link helpers.
- Render an inline card/player for embed helper.
- Record `viewed` when the user opens or plays the tour, not merely when the page renders.
- Record `dismissed` when a modal tour is closed.
- Record `cta_clicked` when the CTA is used.

## Dashboard

Mounted at `/product_tours` by default.

Pages:

- tour index
- new tour
- edit tour
- show tour
- event summary

Index filters:

- status
- kind
- key
- tenant
- recently viewed

Dashboard requirements:

- Development-only access by default.
- Host-configured admin gate for production use.
- No dependency on host CSS framework.
- Preview the video URL on show/edit pages.
- Show event counts for each tour.

## Video Sources

v0.1 accepts:

- YouTube
- Vimeo
- Loom
- Tella
- direct MP4/WebM URLs

Provider handling:

- Normalize supported provider URLs into embeddable players where practical.
- Use a direct `<video>` player for direct media URLs.
- Record completion only where completion can be detected reliably.
- Fall back to `viewed` and `dismissed` for providers without reliable completion events.

## I18n

The gem UI uses keys under:

```yaml
product_tours:
```

v0.1 stores tour content as plain strings. Localized tour fields are deferred unless required by the first integration.

## Privacy And Security

- Dashboard access must be explicitly gated outside development.
- Event/write endpoints should be rate-limited.
- Do not store full request params.
- Do not require storing sensitive query strings in `page_url`.
- Store host user references as loose strings, not foreign keys.
- Do not expose raw Active Storage blob URLs in v0.1.
- Use CSP-compatible scripts with request nonces where inline script is unavoidable.

## Acceptance Criteria

- Fresh install works in a Rails 7.1+ dummy app.
- The generated initializer boots with safe defaults.
- The dashboard is inaccessible outside development unless `authorize_admin` allows access.
- `product_tour_button(:key)` renders only for a published available tour.
- Clicking a product tour button opens a player without a full page reload.
- Opening or playing a tour records a `viewed` event.
- Closing a modal tour records a `dismissed` event.
- CTA clicks are recorded when a CTA is configured.
- Tenant-specific tours override global tours with the same key.
- The widget works with Turbo Drive.
- The widget works under nonce-based CSP.
- Tests cover helpers, dashboard authorization, tour lifecycle, event recording, and tenant scoping.

## README Positioning

Hero:

> Product tours for Rails.

Subhead:

> Add in-app video guides, manage them from a dashboard, and track what users watched. Your app, your database, no third-party widget.

Comparison:

| | Product Tours | Hardcoded embeds | Product-tour SaaS |
| --- | --- | --- | --- |
| Content managed by admins | Yes | No | Yes |
| Stored in your database | Yes | No | No |
| Third-party script | No | Maybe | Yes |
| Per-tenant tours | Yes | Manual | Usually paid |
| View tracking | Yes | Manual | Yes |
| Rails install | One generator | Custom code | Script/config |

## Roadmap

v0.1:

- URL-based video tours
- button/link/embed helpers
- modal player
- dashboard
- events
- tenant scoping

v0.2:

- localized tour fields
- show-once and show-until-watched helpers
- CTA tracking refinements
- seed/import/export workflow

v0.3:

- Active Storage uploads
- transcript field
- poster image handling for uploaded videos
- public read API

v1.0:

- stable API
- polished README and screenshots
- demo app
- upgrade guide
