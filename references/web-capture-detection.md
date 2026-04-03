# Web Capture and Social Post Detection

Shared reference for identifying externally captured content in a vault. Used by `inbox-sort`, `note-rename`, and other skills that need to distinguish user-authored notes from imported content.

## Detection Rules (in priority order)

| # | Signal | Location | Result |
|---|--------|----------|--------|
| 1 | `clippings` tag in YAML frontmatter | `tags:` field | Web capture |
| 2 | `source:` URL in YAML frontmatter (no clippings tag) | `source:` field | Web capture |
| 3 | Bare-link note (just a URL, no real content) from social platform | Body | Social post |
| 4 | Bare-link note from other URL | Body | Web capture |
| 5 | Inline `#clippings` hashtag in body | Body | Web capture |

**Social platforms:** x.com, twitter.com, linkedin.com, instagram.com, threads.net, mastodon.social (and instances).

## Naming Prefix

When a skill renames a detected capture:
- Web capture → `WebCapture - [Clean Title]`
- Social post → `Social - [Clean Title]`

**Skip** notes that already have a categorical prefix (`Analysis -`, `Trading -`, `Supplier -`, etc.).

## Clean-Up Rules for Titles

- Remove browser artifacts like leading `(5) ` (tab count)
- Remove trailing dots and extra spaces
- Truncate at ~55 characters (total under 70 with prefix)
- Preserve the core topic
