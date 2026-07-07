---
title: Template Inheritance
description: Compose layouts with tl:extends and override named blocks with tl:define.
weight: 70
---

Template inheritance lets a page build on a shared layout, overriding named
blocks. It is the layout-composition counterpart to
[fragments](/docs/syntax/fragments/).

## `tl:extends` – inherit a layout

Put `tl:extends` on the **root element** of a child template, naming the parent
layout it builds on:

```html
<html tl:extends="layouts/base.html" lang="en">
  ...
</html>
```

`tl:extends` value cannot be empty, and it must appear only on the root element.

## `tl:define` – define or override a block

`tl:define` names a block. The parent layout declares blocks with `tl:define`;
a child template overrides them by declaring `tl:define` with the same name:

```html
<!-- layouts/base.html — the parent declares blocks -->
<html>
  <body>
    <main tl:define="content">
      <p>Default content.</p>
    </main>
  </body>
</html>
```

```html
<!-- child.html — overrides the "content" block -->
<html tl:extends="layouts/base.html">
  <body>
    <main tl:define="content">
      <h1>My page</h1>
      <p>This replaces the default content.</p>
    </main>
  </body>
</html>
```

Block names must be unique within a template – a duplicate `tl:define` name is
reported as an error. A `tl:define` value cannot be empty.

> This is exactly how the Arbor documentation theme is built: a `base.html`
> layout declares `content`, `site-header`, and `site-footer` blocks, and each
> page layout extends it and overrides `content`.
