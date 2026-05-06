---
title: Note with link
created: 2026-05-06
---

# Note with link

This note lives **inside** the trailing-dot folder. It contains a wikilink to `target-outside`, which lives at the fixture root.

A skill that fails to descend into the trailing-dot folder will not see this file. As a result:

1. A rename pass run against this fixture will not touch this note (silent skip).
2. If `target-outside.md` is renamed, the wikilink below will break — and the skill will not know it broke, because it never saw the source file in the first place.

See: [[target-outside]]
