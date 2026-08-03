# product_tours

[![CI](https://github.com/yshmarov/product_tours/actions/workflows/ci.yml/badge.svg)](https://github.com/yshmarov/product_tours/actions/workflows/ci.yml)
[![MIT License](https://img.shields.io/badge/license-MIT-blue.svg)](MIT-LICENSE)

`product_tours` is a self-hosted Rails engine for in-app product tutorials and
lightweight multi-step walkthroughs. Your app owns the trigger UI; the gem owns
the tutorial editor, translations, safe video embeds, and modal navigation.

Requires Ruby 3.2+ and Rails 7.1+.

## Install

```ruby
gem "product_tours"
```

```bash
bin/rails generate product_tours:install
bin/rails db:migrate
```

The migration automatically creates ready-to-use demo tutorials in development.
Production databases are never populated with demo content.

Add the widget before `</body>` in your application layout:

```erb
<%= product_tours_tag %>
```

Use any host-owned button, link, or icon as the trigger:

```erb
<button class="btn btn-primary" data-product-tour="billing_setup">
  Watch setup guide
</button>
```

Create and publish `billing_setup` in the dashboard at `/product_tours`. Keys
are unique per locale. Draft, missing, invalid, or disabled keys open nothing
and raise in development/test; production reports them through `Rails.error`
and `product_tours.unresolved_trigger` instrumentation.

### Host-controlled invocation

The host app decides where and when a guide opens. It can use a visible button,
compose several buttons into its own Help menu, or activate a hidden trigger
after page load. For example, Rails flash state and a host Stimulus controller
can open a guide after a redirect:

```erb
<% if flash[:product_tour].present? %>
  <button hidden
          data-controller="product-tour-autoplay"
          data-product-tour="<%= flash[:product_tour] %>"></button>
<% end %>
```

```js
// product_tour_autoplay_controller.js in the host app
connect() {
  this.element.click()
}
```

The gem deliberately has no page-rule engine, automatic display scheduler,
resource center, or guides launcher. Those are host navigation and presentation
choices built from the same `data-product-tour` attribute.

## Tutorials

A tutorial is stored internally as a `ProductTours::Post`. It has a title, key,
locale, `draft`/`published` status,
optional video, optional rich description, and one primary action. Video URLs
support YouTube, Vimeo, Loom, Tella, Voomly, and direct MP4/WebM files.

The dashboard previews a pasted video URL immediately. YouTube, Vimeo, and Loom
metadata is fetched through oEmbed; the other supported providers still get a
safe resolved preview. Direct videos seek to an early frame so they do not look
like an empty player before playback.

The admin sidebar treats `I18n.default_locale` as the canonical tutorial list.
The New product tour button always creates that default-language record. Open a
tutorial to see its existing languages or add another available locale; each
translation remains an ordinary draft/published `Post` with the same key.

When the host has a Rails Content Security Policy, the engine preserves its
existing `frame-src` entries and automatically adds the supported embed origins.
For a direct video hosted on a custom origin, the host remains responsible for
allowing that origin in `media-src` (or can allow HTTPS media generally).

### Link tutorials into a walkthrough

In the tutorial editor, choose what the primary button does: finish and close,
open a page, or continue to another tutorial. Continuing opens the selected
tutorial in the
same modal and automatically gives visitors a Back button.

Tutorials remain independently invokable—there is no separate course, step, or
sequence model. The Back history exists only for the open modal, so a tutorial opened
directly never shows a misleading Back button.

Video uploads require Active Storage:

```bash
bin/rails active_storage:install
bin/rails db:migrate
```

Rich descriptions require Action Text:

```bash
bin/rails action_text:install
bin/rails db:migrate
```

The post form hides either feature when its Rails framework is not installed.

## Demo tutorials

The installer seeds the app's default locale in development. Copy the block it
prints into any ERB view to open every demo entry point immediately:

```erb
<div class="product-tours-demo">
  <button type="button" data-product-tour="demo_walkthrough_start">Try the multi-step walkthrough</button>
  <button type="button" data-product-tour="demo_youtube">Open the YouTube tutorial</button>
  <button type="button" data-product-tour="demo_vimeo">Open the Vimeo tutorial</button>
  <button type="button" data-product-tour="demo_loom">Open the Loom tutorial</button>
  <button type="button" data-product-tour="demo_tella">Open the Tella tutorial</button>
  <button type="button" data-product-tour="demo_voomly">Open the Voomly tutorial</button>
  <button type="button" data-product-tour="demo_direct_video">Open the direct video tutorial</button>
  <button type="button" data-product-tour="demo_getting_started">Open the getting started guide</button>
  <button type="button" data-product-tour="demo_draft">Try an unpublished tutorial</button>
  <button type="button" data-product-tour="demo_missing_post">Try a missing tutorial</button>
</div>
<%= product_tours_tag %>
```

`demo_walkthrough_start` introduces the collection, then continues through the
YouTube, Vimeo, Loom, Tella, Voomly, and direct-video tutorials before its final
step. Every transition demonstrates the automatic Back button. The individual
provider buttons remain available so each video can also be opened directly.
The final two buttons deliberately exercise unresolved triggers: `demo_draft`
exists but remains unpublished, while `demo_missing_post` is never seeded.

Refresh the full idempotent demo set in English, French, and Bulgarian at any
time:

```bash
bin/rails product_tours:seed_demo
```

Along with the provider examples, it creates `demo_walkthrough_start`,
`demo_walkthrough_features`, `demo_walkthrough_finish`, and the unpublished
`demo_draft` in the default demo locales (`en`, `fr`, and `bg`). The missing-key
button intentionally has no matching record. Running the task again refreshes
the seeded records instead of duplicating them and prints the copy-ready block
again. To seed only one locale from application code, call
`ProductTours::Seeds.load!(locale: :fr)`.

## Configuration

The installer creates `config/initializers/product_tours.rb`. Important hooks:

```ruby
ProductTours.configure do |config|
  config.authorize_admin = ->(request) { request.env["warden"]&.user&.admin? }
end
```

Tutorial lookup automatically uses the page's current `I18n.locale`, then falls
back to `I18n.default_locale` when that key has no current-locale record. An
existing draft translation is not bypassed by the fallback.

## Lifecycle Notifications

The widget emits `product_tours.viewed`, `product_tours.dismissed`, and
`product_tours.completed` through `ActiveSupport::Notifications`. The gem does
not persist analytics and does not depend on Ahoy. `completed` means the visitor
used the tutorial's primary action; video playback does not imply completion.

```ruby
ActiveSupport::Notifications.subscribe(/^product_tours\./) do |name, _start, _finish, _id, payload|
  Ahoy.track(name.delete_prefix("product_tours."), payload.slice(:key, :locale, :source))
end
```

The host may store these events with Ahoy and attach its own user or account
context in the subscriber. Persistence, dashboards, identity, and vendor-specific
integrations remain outside this gem.

## Scope

`product_tours` owns tutorial persistence and editing, safe media rendering, the
modal experience, linked-tutorial navigation, and lifecycle notifications. The host
app owns trigger timing and placement, Help/resource menus, analytics storage,
reporting, and downstream integrations.

## Development

```bash
bundle install
bundle exec rake test
bundle exec rubocop
```

Rails 7.1+ and Ruby 3.2+ are supported.
