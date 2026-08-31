---
title: Folio records
layout: home
description: A reusable field guide for careful observations and long-form reference.
featured:
  label: In this volume
  title: Entries and reference material.
  body: Every page in the guide, listed from the content tree. Add a folder and the index follows.
hero:
  caption: Sea lavender, recorded after the spring tide. Graphite and green ink.
  ctas:
    - {label: Open the manual, href: /docs/, style: primary}
    - {label: Browse specimens, href: /docs/apparatus/, style: secondary}
apparatus:
  label: Field apparatus
  title: Content keeps its natural shape.
  body: >-
    Figures, captions, and sidenotes remain semantic page content. The theme adds hierarchy and notation without
    inventing a private content model.
  plate:
    caption: Semantic apparatus stays portable, readable, and useful without the theme.
    code: |
      <!-- ordinary page content -->
      <figure class="folio-plate">
        <img src="saltmarsh.svg"
             alt="Saltmarsh zonation study">
        <figcaption>Transect after high tide.</figcaption>
      </figure>

      <aside class="folio-sidenote">
        Salinity fell sharply beyond station four.
      </aside>
  sidenote:
    label: Margin note
    body:
      - The numbered plate is a real figure element. Its caption remains a figcaption; this note remains an aside.
      - Disable numbering or sidenotes without removing the source content.
principles:
  label: Characteristics
  title: Designed for material that rewards attention.
  items:
    - number: "01"
      title: Reference first
      body: Calm hierarchy, narrow reading measures, and visible navigation support sustained use.
    - number: "02"
      title: Rubricated sparingly
      body: The red accent is reserved for labels, plate numbers, and important annotations.
    - number: "03"
      title: Content remains content
      body: Ordinary headings, figures, captions, and asides carry the structure.
manual:
  label: Representative docs view
  title: The observer's manual
  body: >-
    A complete documentation surface: searchable section tree, article landmarks, table of contents, highlighted
    examples, and previous/next travel.
  cta: {label: Open the manual, href: /docs/}
---

Folio arranges observations, semantic plates, and reference notes without imposing a private content
model. Figures stay `<figure>`, captions stay `<figcaption>`, and margin notes stay `<aside>`, so the
same source reads correctly in another theme or with no theme at all.

Plate numbering, sidenotes, search, and the in-page index are each a single parameter, and every one of
them can be switched off without touching a line of content.
