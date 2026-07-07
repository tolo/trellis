---
title: Inline Processing
description: Embed expressions directly in text, script, and style content with tl:inline.
weight: 90
---

`tl:inline` enables inline expression syntax inside an element's text content,
so you can interpolate values without wrapping every one in its own `tl:text`
element.

## `tl:inline` – inline expressions

Set `tl:inline` to the content mode. Inside the element, `[[${expr}]]` emits
escaped output and `[(${expr})]` emits unescaped output:

```html
<p tl:inline="text">Hello, [[${name}]]! Today is [(${rawHtml})].</p>
```

The supported modes are `text`, `javascript`, `css`, and `none`.

### JavaScript blocks

```html
<script tl:inline="javascript">
  var user = [[${user.name}]];
</script>
```

### Style blocks

```html
<style tl:inline="css">
  .alert { color: [[${alertColor}]]; }
</style>
```

> **Security:** in `javascript` and `css` modes, inline output is escaped –
> including `</script>` and `</style>` closing sequences – to prevent context
> breakout.
