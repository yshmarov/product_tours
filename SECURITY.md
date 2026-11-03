# Security policy

## Supported versions

Security fixes are released for the latest 1.x version. If a report also
affects the newest 0.x release, a backport may be published when the fix is
small and the affected application cannot upgrade immediately.

## Reporting a vulnerability

Please do not open a public issue for a vulnerability. Use
[GitHub private vulnerability reporting](https://github.com/yshmarov/product_tours/security/advisories/new)
and include the affected version, a minimal reproduction, impact, and any known
workaround. Credentials, session cookies, private application URLs, customer
content, uploaded videos, and production database contents should not be
included.

Public disclosure should wait until a fixed version is available and affected
users have had a reasonable opportunity to upgrade.

## Data and deployment boundary

The public widget resolves only published tours allowed by `config.enabled`,
which defaults to everyone because showing tutorials in production is the gem's
purpose. The dashboard is separately protected by `authorize_admin` and fails
closed outside development until the host explicitly grants access.

A tour can store its key, locale, status, title, video URL and metadata, poster and
captions URLs, primary action label/destination, timestamps, optional Action Text description, and an
optional Active Storage video. Uploaded videos stream through the engine's
authorization gate with private, non-stored responses; the route never redirects
to a reusable signed blob URL. Hosts still own the storage service, bucket
policy, backups, retention period, access controls, and incident response.

The gem emits lifecycle events containing a tour id, key, locale, query-free
page URL, and source, but does not persist visitor events, identity, progress,
or completion. A host's `on_event` hook receives the raw request; anything it
derives or persists is part of the host application's own privacy boundary.

Delete a tour with ordinary Active Record when an application policy requires
erasure:

```ruby
ProductTours::Tour.find(id).destroy!
```

That removes the record and lets Rails apply the configured Action Text and
Active Storage attachment lifecycles. Confirm deletion separately in object
storage, replicas, backups, caches, analytics, and exports; deleting the live
row does not rewrite them.
