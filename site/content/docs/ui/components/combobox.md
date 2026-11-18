---
title: Combobox
description: Choose a submitted value from a list of suggestions.
layout: ui_component
component: combobox
tokens: [--input, --popover, --popover-foreground, --accent, --accent-foreground, --ring, --radius]
options:
  - {value: apple, label: Apple}
  - {value: apricot, label: Apricot}
  - {value: banana, label: Banana}
---

Choose a fruit with the keyboard or open suggestions using the chevron.
The live example starts with three options.

## Example

<!-- tl:ui_combobox -->

```html
<label tl:replace="~{trellis-ui/field :: label('reference-fruit')}">Fruit</label>
<div tl:replace="~{trellis-ui/combobox :: combobox('reference-fruit', 'fruitId', 'Choose a fruit', 'banana', options, 'Banana')}"></div>
```

Supply these options in site front matter or the application’s render context.

```yaml
options:
  - {value: apple, label: Apple}
  - {value: apricot, label: Apricot}
  - {value: banana, label: Banana}
```

## Keyboard interaction

Tab reaches the text input. ArrowDown and ArrowUp move through suggestions.
Enter selects the highlighted suggestion. Escape closes the popup. Home and
End retain their text-editing behavior.

## Accessibility notes

Use a visible label with the same ID as the combobox. The fragment submits
the selected ID via the hidden field named by the `name` argument. The
`displayValue` argument sets the initial text. Editing clears the selected ID.

## Server filtering

Supply initial options as maps with `value` and `label`. The static options stay
the same as you type. For live filtering, pass the query field name and HTMX
attributes to the visible input through `...attrs`. Filter the query on the
server, then render `comboboxOptions` with the same base ID and swap the
results container.

```html
<div tl:replace="~{trellis-ui/combobox :: combobox('fruit', 'fruitId', 'Search fruits', '', options)}"
  name="q" hx-get="/fruit/options" hx-trigger="input changed delay:200ms"
  hx-target="#fruit-results" hx-swap="outerHTML" hx-sync="this:replace"></div>
```

```dart
final html = engine.renderFileFragment('trellis-ui/combobox', fragment: 'comboboxOptions', context: {
  'id': 'fruit',
  'options': matches,
});
```
