# AGENTS.md

Instructions for coding agents. Two audiences:

- **[Installing product_tours into a Rails app](#installing-into-a-rails-app)** — you are working in a host app and were asked to add product tours, onboarding guides, or video tutorials.
- **[Working on the gem itself](#working-on-the-gem-itself)** — you are working in this repository.

Requirements: Ruby >= 3.2, Rails >= 7.1. Active Storage only for uploaded videos, Action Text only for rich descriptions — both optional and both degrade rather than raise.

If you are in a host app and this file is not in front of you, it ships inside the gem: `cat "$(bundle show product_tours)/AGENTS.md"`.

---

## Installing into a Rails app

### 1. Install

```bash
bundle add product_tours
bin/rails generate product_tours:install
bin/rails db:migrate
```

The generator writes `config/initializers/product_tours.rb`, one migration (`product_tours_posts`), and `mount_product_tours at: "/product_tours"` into `config/routes.rb`. **In development the migration also inserts working demo tutorials**, so the modal has something to open before anyone has written content. Read the initializer it wrote — it is the source of truth over any summary of it, including this file.

### 2. Wire the three things the generator cannot

**a. The widget tag**, once, in the layout:

```erb
<%# app/views/layouts/application.html.erb, before </body> %>
<%= product_tours_tag %>
```

The helper is injected into ActionView by the engine — no include, no import, no asset pipeline entry.

**b. A trigger**, wherever the tutorial is useful. This is the part that makes it different from a SaaS tour builder: nothing auto-attaches to DOM nodes, you put the button where it belongs.

```erb
<button data-product-tour="billing_setup">Watch the billing guide</button>
```

The value is a tutorial **key**, and the key must exist and be **published** or the trigger does nothing.

**c. `authorize_admin` — do this before deploying.** The dashboard at `/product_tours` defaults to **development only**. It fails closed, so shipping without this is not an open dashboard — it is a 403 reading "Forbidden. Set ProductTours.config.authorize_admin to grant access."

```ruby
config.authorize_admin = ->(request) { request.env["warden"]&.user&.admin? }
```

> **`enabled` and `authorize_admin` receive the raw `request`, not a controller.** Writing `->(request) { current_user }` is the most common mistake here — that method does not exist in this scope. Resolve the user *from the request*: Warden env, a signed cookie, `Current.user` if middleware already set it.

```ruby
# Rails 8 built-in auth
config.authorize_admin = lambda do |request|
  token = request.cookies["session_token"]
  Session.find_signed(token)&.user&.admin? || false
end
```

### 3. Verify

```bash
bin/rails routes | grep product_tours     # engine mounted
bin/rails product_tours:seed_demo         # refresh demo tutorials in every locale
```

Then in the running app: open `/product_tours`, confirm the demo tutorials are listed, and click a `data-product-tour` button on one of your own pages.

### Tutorials are content, not code

A tutorial is a row in `product_tours_posts`, written and published in the mounted dashboard. **Do not create tutorials from host-app migrations, seeds, or fixtures** — that is not how this gem is meant to be used, and it puts editorial content in schema history. If the app needs sample content, `bin/rails product_tours:seed_demo` is the supported path.

What a tutorial carries: a `key`, a title, an optional rich description, an optional video, and at most one primary action (a URL, or the key of the next tutorial — that link is what makes a walkthrough). Keys must match `/\A[a-z0-9]+(?:[._-][a-z0-9]+)*\z/` — lowercase, digits, and `. _ -` as separators. `Billing Setup` and `billingSetup` are invalid; `billing_setup` and `billing.step-1` are fine. `status` is `draft` or `published`, and the key is unique **per locale**, which is how translations work: one row per language for the same key, with locale fallback at resolve time.

### Video providers

YouTube, Vimeo, Loom, Tella, Voomly, a direct MP4/WebM URL, or an uploaded file (needs Active Storage). Uploaded videos stream through the engine at `/product_tours/media/:id` — not a public blob URL. Do not build your own blob links.

**The engine edits the app's Content Security Policy.** It appends the providers' embed hosts to `frame-src` (or to `default-src` when `frame-src` is unset) in an initializer that runs after the host's own. That is deliberate — an embed silently blocked by CSP is a bad first five minutes — but know it happens, and do not hand-add those `frame-src` entries yourself. If the app sets its CSP somewhere unusual (a middleware, a per-controller override), that is where a blocked embed will come from.

### Lifecycle events

Subscribe in an initializer; there is no callback config to set.

```ruby
ActiveSupport::Notifications.subscribe("product_tours.completed") do |*, payload|
  # payload has the tutorial key and request context
end
```

Names: `product_tours.viewed`, `product_tours.dismissed`, `product_tours.completed`, and `product_tours.unresolved_trigger` — the last one fires when a `data-product-tour` button names a key that does not resolve. Subscribe to it in development; it turns "my button does nothing" into a log line naming the key.

### Do not

- **Do not copy the widget JavaScript into `app/javascript`, or add a `<script>` tag for it.** `product_tours_tag` renders what is needed and the engine serves the code. There is no build step and nothing for esbuild/importmap/Tailwind to know about.
- **Do not create or edit tutorials in code** (see above).
- **Do not add provider hosts to `frame-src` by hand** — the engine already does it.
- **Do not serve uploaded videos by blob URL** — the gated media route exists so a leaked signed URL cannot hand over your content.
- **Do not install Active Storage or Action Text "to make it work"** unless the app actually wants uploads or rich text. Both are optional; the gem checks for them (`Post.video_upload_supported?`, `Post.description_supported?`) and simply offers less.

### Configuration

There are five options. That is the whole surface.

| Option | Default | What it does |
| --- | --- | --- |
| `authorize_admin` | development only | **Who can read and edit tutorials. Set before deploying.** |
| `enabled` | everyone | Per-request gate for the widget and its endpoints |
| `admin_layout` | `product_tours/application` | Render the dashboard inside your admin shell |
| `mount_path` | `"/product_tours"` | Keep in sync with `mount_product_tours at:` |
| `storage_service` | app default | Active Storage service for uploaded video (a `storage.yml` key) |

26 locales ship with the gem, RTL included.

### Common failure modes

| Symptom | Cause |
| --- | --- |
| The trigger button does nothing | No tutorial with that key, or it is still a draft, or `product_tours_tag` is missing from the layout. Subscribe to `product_tours.unresolved_trigger` to see which |
| `/product_tours` returns 403 "Set ProductTours.config.authorize_admin to grant access" | Exactly what it says: still at the development-only default |
| Key rejected on save | It must match `/\A[a-z0-9]+(?:[._-][a-z0-9]+)*\z/` — no capitals, no spaces |
| Video area blank for an embed | CSP. The engine appends provider hosts to `frame-src`; a policy set outside `config.content_security_policy` will not have them |
| No upload option on the form | Active Storage not installed |
| No rich-text editor for the description | Action Text not installed |
| Duplicate-key error when adding a translation | The key is unique per locale — add the translation from the tutorial page rather than creating a second record by hand |

---

## Working on the gem itself

```bash
bundle exec rake test            # minitest, dummy app under test/dummy
bundle exec rubocop              # must be clean
BUNDLE_GEMFILE=gemfiles/rails_7.1.gemfile bundle exec rake test   # 7.1, 7.2, 8.0, 8.1 in gemfiles/
```

Layout: `app/` controllers, `Post`, dashboard views · `lib/product_tours/` config, widget JS, seeds, engine, CSP patch · `lib/generators/product_tours/install/` the one generator · `config/locales/` 26 locales · `test/` minitest with `test/dummy` as the host app.

Conventions this codebase holds to — follow them rather than the first thing that works:

- **Optional dependencies are checked, never assumed.** `has_rich_text` is declared only `if respond_to?`, `has_one_attached` only `if defined?(::ActiveStorage)`, and the model exposes `description_supported?` / `video_upload_supported?` so views can offer less instead of raising. An app with neither gem must boot and work.
- **Triggers are explicit.** The gem never guesses at DOM nodes or auto-starts a tour; a host puts `data-product-tour="key"` where it wants it. A trigger naming a key that does not resolve is instrumented, not silently swallowed.
- **The widget is plain JS served by the engine** — no build step, no framework, no CDN.
- **Uploaded media streams through the engine's gate**, never a public blob URL.
- **The CSP patch is additive.** It appends to existing sources and drops `'none'` rather than replacing a host's policy — do not let it start overwriting directives.
- **The dummy app pins `config.active_job.queue_adapter = :test`.** Do not remove it or let it drift back to the `:async` default. Attaching a video enqueues Active Storage's analysis job, and `:async` runs it on a background thread that checks out its own connection — writes no test transaction covers, landing in the middle of whatever runs next. That is a suite that fails order-dependently in a test which never created a row, and it is miserable to trace back.
- Every user-facing change bumps `lib/product_tours/version.rb` and adds a `CHANGELOG.md` entry (Keep a Changelog format) that says what it costs, not only what it adds.
- Commit messages are prose that explains the tradeoff — read `git log` before writing one.
