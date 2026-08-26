---
title: Choosing a content shape
date: 2024-02-19
author: Ada Whitlock
summary: Front matter is a schema whether you plan it or not. A few notes on keeping it honest.
tags:
  - dart
  - trellis
---

Every field you add to front matter is a promise to every future page. The cost shows up later, when a template
assumes a key that half the archive never had.

## Keep optional things optional

Guard on presence, not on truthiness. An empty string and an empty list are values, and templates that treat them
as absent will render empty buttons and stray rules.

## Let the tree carry structure

Sections, ordering, and navigation can all come from the folder layout. That is one less thing to keep in sync by
hand.
