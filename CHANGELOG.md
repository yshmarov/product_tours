# Changelog

## [Unreleased]

## [0.3.1] - 2026-08-08

- **Hosts can handle lifecycle events with their own request context.** Set
  `config.on_event` to a callable accepting `(name, payload, request)` when a
  `viewed`, `dismissed`, or `completed` signal must resolve a signed session,
  user, account, or tenant that deliberately does not belong in the gem. The
  existing `ActiveSupport::Notifications` events and their minimal payloads are
  unchanged. The hook runs inline, so slow work should be enqueued; exceptions
  are logged and never turn a working tutorial action into a visitor-facing
  failure.

## 0.3.0

- **One design system across the family.** The stylesheet now opens with a
  shared core — the colour tokens, `.page-head`, `.tabs`, `.filters`, `.card`,
  `.badge`, buttons and form controls, and the `.dashboard-shell` +
  `.record-row` + `.detail-panel` two-pane dashboard — identical in all five
  gems of the family, apart from the `--pt-` prefix. The five had drifted:
  sidebars between 380px and 430px, reading columns between 860px and 1020px,
  two different tab styles and three different button styles. The sidebar is
  now 330–430px everywhere, a reading page 1020px, a dashboard 1280px.
  Everything below the `GEM-SPECIFIC` banner is what only this gem has.
- **The dashboard markup uses the shared class names.** `.post-panel` is
  `.detail-panel`; everything else already used the shared vocabulary, which
  this gem's dashboard had the most of. If you styled or scripted
  `.post-panel` in a host app, that is the breaking change — no configuration,
  route or database change is involved.
- **The narrow-screen rules work again.** The `max-width: 760px` block sat above
  the component rules it means to override, and CSS nesting adds no specificity,
  so the desktop grid won every tie: showing one pane at a time on a phone had
  quietly stopped working. The media query moved to the end of the file.
- Smaller fixes that came with the shared core: a submit input is styled as a
  button rather than a full-width field, the filter row keeps its search box and
  button on one line, and a `code.key` truncates inside a list row instead of
  wrapping over three lines.

## 0.2.0

- **`config.admin_layout` now works on its own.** The dashboard's stylesheet and
  script were declared in the gem's layout, so replacing that layout dropped
  both and the dashboard rendered unstyled with its client-side behaviour dead.
  They move into the views, so every layout gets them with nothing asked of the
  host.
- **The dashboard stylesheet no longer claims selectors it does not own.** It
  styled bare `*`, `html`, `body` and `a`, and its `.container`, `.card` and
  `.tabs` are names other frameworks use too, so a host that did load it had its
  own chrome restyled. Component rules now nest inside a `.pt-dashboard` wrapper
  the views render, and every custom property is `--pt-` prefixed so it can
  neither overwrite a host's nor be overwritten. The page-frame rules stay keyed
  to the body classes only the gem's own layout sets.
- **Added `config.base_controller_class`.** Name the controller your own admin
  inherits from and the dashboard adopts its layout, helpers, authentication and
  request context — the things `admin_layout` cannot give you. It reparents the
  dashboard only; the widget, tour-resolution and media endpoints stay on the
  engine's public controller, so it can never demand a staff session from a
  visitor. Default is unchanged.
- **Migrations follow the host's `primary_key_type`,** the same
  `Rails.configuration.generators` lookup Rails' own Active Storage, Action Text
  and Action Mailbox migrations do. A uuid-keyed app has a uuid
  `active_storage_attachments.record_id`, so a bigint table here could never
  hold a video: `attach` raised `NotNullViolation`. A host that set nothing gets
  an identical migration to before.
- **Dropped the `id: /\d+/` constraint on the media route,** which was what
  forced the table to be bigint. It was never load-bearing: every fixed-name
  route is declared first.
- **Dropped the redundant `(locale)` index.** A B-tree serves any leftmost
  prefix, so `(locale, key)` already covered it; it only cost write time and
  disk. Existing installs keep theirs until they drop it:
  `remove_index :product_tours_posts, :locale`.
- A `BackboneTest` now fails the build on any of the above regressing.

## [0.1.2] - 2026-08-04

- Added `AGENTS.md`: install and integration instructions written for coding
  agents — that tutorials are content managed in the dashboard rather than
  created from migrations, the key format, the request-shaped config lambdas,
  that the engine appends provider hosts to the app's `frame-src`, and the
  `product_tours.unresolved_trigger` notification that turns "my button does
  nothing" into a log line. It ships inside the gem, so
  `cat "$(bundle show product_tours)/AGENTS.md"` works from a host app.
- The dummy app pins `queue_adapter = :test` for the test suite. Attaching a
  video enqueues Active Storage's analysis job, and the default `:async` adapter
  runs it on a background thread with its own database connection — writes no
  test transaction covers, which is how a suite starts failing order-dependently
  in a test that never created a row. No effect on the gem itself.

## [0.1.1] - 2026-08-04

- Reworked the README into an installation-first, skimmable product guide that
  accurately documents walkthroughs, video providers, translations, demo data,
  configuration, lifecycle events, security, and intentional non-goals.
- Replaced the implementation-era PRD with a concise contract for the shipped
  product boundary and current behavior.
- Added real desktop dashboard, editor, walkthrough, and mobile screenshots from
  the seeded dummy application.

## [0.1.0] - 2026-08-03

- Initial Rails engine, post dashboard, modal widget, video providers,
  lifecycle notifications, installer, and demo seed task.
- Linked Post actions with same-modal navigation, an in-memory Back stack, and
  self-explanatory action choices in the dashboard.
- Development installs now seed provider and multi-step demos automatically;
  the installer and seed task print a copy-ready ERB trigger block.
- Clarified the permanent host/gem boundary: host apps own trigger timing,
  Help menus, analytics persistence, reporting, and vendor integrations.
- Added immediate oEmbed-backed form previews, first-frame direct-video
  previews, automatic CSP `frame-src` merging, language controls, key
  normalization, and a simpler form layout.
- Aligned the public modal shell and mobile behavior with the shared visual
  patterns used by the `testimonials` and `ideasbugs` gems.
- Added explicit Publish and Move to drafts dashboard actions, and linked the
  seeded walkthrough through every supported video provider.
- Aligned the admin dashboard with the shared sibling-gem page, card, queue,
  detail, action, and responsive patterns; post metadata now lives in Details.
- Added copy-ready launchers for a seeded draft post and an intentionally
  missing key so developers can exercise both unresolved-trigger paths.
- Reduced configuration to host gating, layout, mount path, and optional storage;
  locale resolution now follows current then default locale, production failures
  report through `Rails.error`, and lifecycle payloads contain no gem-owned user,
  tenant, or visitor identity.
- Renamed admin-facing records to tutorials, put Published before Draft, made
  identity fields full-width, and replaced simultaneous URL/upload inputs with a
  clear video-source choice.
- Simplified lifecycle notifications to tutorial, page, and source context;
  removed navigation/progress metadata and inconsistent video-ended completion.
- Made the default locale the canonical admin tutorial list; new product tours now
  start in that locale and translations are added and opened from each tutorial.
- Removed generic tutorial duplication now that translations provide the only
  intentional content-copying workflow.

[Unreleased]: https://github.com/yshmarov/product_tours/compare/v0.3.1...HEAD
[0.3.1]: https://github.com/yshmarov/product_tours/compare/v0.3.0...v0.3.1
[0.1.1]: https://github.com/yshmarov/product_tours/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/yshmarov/product_tours/releases/tag/v0.1.0
