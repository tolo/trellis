---
title: Iteration
description: Loop over lists with tl:each and its status variables.
weight: 40
---

`tl:each` repeats an element once per item in a collection.

## `tl:each` – loop

The syntax is `item : ${collection}`. The element is rendered once per item,
with `item` bound in each iteration:

```html
<li tl:each="item : ${items}" tl:text="${item}">placeholder</li>
```

Rendering with `{'items': ['a', 'b', 'c']}` produces three `<li>` elements.

## Status variables

Each loop exposes a status object. By default it is named after the item with a
`Stat` suffix – for `item`, the status is `${itemStat}`. You can give it an
explicit name with `item, stat : ${items}`, which exposes `${stat}`:

```html
<li tl:each="item, s : ${items}"
    tl:classappend="${s.odd} ? 'odd' : 'even'"
    tl:text="${s.count} + '. ' + ${item}">placeholder</li>
```

| Variable | Description |
|---|---|
| `index` | 0-based index |
| `count` | 1-based count |
| `size` | Total number of items |
| `first` | `true` for the first item |
| `last` | `true` for the last item |
| `odd` | `true` for 0-based odd indices |
| `even` | `true` for 0-based even indices |
| `current` | The current item value |

> **Tip:** to loop without emitting a wrapper element, put `tl:each` on a
> [`<tl:block>`](/docs/syntax/output-control/) virtual element.
