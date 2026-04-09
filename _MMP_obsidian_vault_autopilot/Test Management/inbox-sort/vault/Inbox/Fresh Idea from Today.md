---
tags:
  - Ideas
created: DYNAMIC
---

# Fresh Idea from Today

What if we built a browser extension that captures highlighted text directly into Obsidian? Not just the URL, but the selected paragraph with source attribution.

## How It Could Work

1. User highlights text on any webpage
2. Right-click → "Send to Obsidian"
3. Extension creates a new note with the highlighted text, source URL, and timestamp
4. Note lands in the inbox folder for later processing

## Differentiation

Existing clippers (Markdownload, Obsidian Web Clipper) capture entire pages. This would capture only the selected fragment — less noise, more signal.

## Technical Approach

- Chrome extension with Manifest V3
- Obsidian Local REST API plugin as the bridge
- Fallback: write to a shared folder that Obsidian syncs

## Next Steps

- Check if Obsidian Local REST API supports note creation
- Look at existing extension code for reference
- Build a prototype this weekend
