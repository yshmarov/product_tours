# product_tours

`product_tours` is a self-hosted Rails engine for individual in-app tutorials.
Your app owns the trigger UI; the gem owns the post editor and modal.

## Install

```ruby
gem "product_tours"
```

```bash
bin/rails generate product_tours:install
bin/rails db:migrate
```

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

## Posts

A `ProductTours::Post` has a title, key, locale, `draft`/`published` status,
optional video, optional rich description, and one primary action. Video URLs
support YouTube, Vimeo, Loom, Tella, Voomly, and direct MP4/WebM files.

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

## Demo Posts

Create an idempotent provider matrix with published posts in English, French,
and Bulgarian:

```bash
bin/rails product_tours:seed_demo
```

It creates `demo_youtube`, `demo_vimeo`, `demo_loom`, `demo_tella`,
`demo_voomly`, `demo_direct_video`, and `demo_getting_started` in the default
demo locales (`en`, `fr`, and `bg`). Running the task again refreshes those
records instead of duplicating them. To seed only one locale from application
code, call `ProductTours::Seeds.load!(locale: :fr)`.

## Configuration

The installer creates `config/initializers/product_tours.rb`. Important hooks:

```ruby
ProductTours.configure do |config|
  config.authorize_admin = ->(request) { request.env["warden"]&.user&.admin? }
  config.current_user = ->(request) { request.env["warden"]&.user }
  config.tenant = ->(_request) { Current.organization&.to_gid&.to_s }
  config.locale = ->(_request) { I18n.locale }
end
```

`tenant` is notification context only. Posts are never tenant-scoped.

## Lifecycle Notifications

The widget emits `product_tours.viewed`, `product_tours.dismissed`, and
`product_tours.completed` through `ActiveSupport::Notifications`. The gem does
not persist analytics.

```ruby
ActiveSupport::Notifications.subscribe(/^product_tours\./) do |name, _start, _finish, _id, payload|
  Ahoy.track(name.delete_prefix("product_tours."), payload.slice(:key, :locale, :tenant, :source))
end
```

## Development

```bash
bundle install
bundle exec rake test
bundle exec rubocop
```

Rails 7.1+ and Ruby 3.2+ are supported.
