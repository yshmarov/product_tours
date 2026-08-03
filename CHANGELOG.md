# Changelog

## [Unreleased]

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

[Unreleased]: https://github.com/yshmarov/product_tours/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/yshmarov/product_tours/releases/tag/v0.1.0
