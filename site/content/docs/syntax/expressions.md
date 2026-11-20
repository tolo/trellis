---
title: Expressions
description: The Trellis expression language – variables, selection, URLs, messages, literals, arithmetic, ternary, Elvis, comparisons, boolean logic, filters, utility objects, and the no-op.
weight: 10
---

Almost every `tl:*` attribute takes an *expression* as its value. This page is
the complete reference for the expression language. Learn it once and it applies
in `tl:text`, `tl:if`, `tl:each`, `tl:attr`, and everywhere else.

## Variable expressions – `${...}`

`${...}` reads a value from the rendering context. Paths use dot notation and
traverse maps and objects null-safely:

```html
<p tl:text="${user.name}">name</p>
```

Given the context `{'user': {'name': 'Ada'}}` this renders `<p>Ada</p>`.

### Dynamic index access

Index into a list or map with a bracket expression:

```html
<p tl:text="${items[index]}">item</p>
```

The index itself is an expression, so `${items[i + 1]}` and `${map['key']}` both
work. Refer to variables inside the brackets by bare name: a nested `${...}`, as
in `${items[${i}]}`, is an error.

## Selection expressions – `*{...}`

Inside an element carrying [`tl:object`](/docs/syntax/local-variables/), `*{...}`
reads a field of the selected object directly, without repeating its name:

```html
<div tl:object="${user}">
  <span tl:text="*{name}">name</span>
  <span tl:text="*{email}">email</span>
</div>
```

## URL expressions – `@{...}`

`@{...}` builds a URL, optionally with query parameters supplied as
`name=${value}` pairs in parentheses:

```html
<a tl:href="@{/users(id=${userId})}">profile</a>
```

With `userId` = `42` this produces `href="/users?id=42"`.

## Message expressions – `#{...}`

`#{...}` looks up an internationalized message by key from a configured
`MessageSource`. Positional arguments are passed in parentheses:

```html
<p tl:text="#{welcome.title}">Welcome</p>
<p tl:text="#{greeting(${user.name})}">Hello, user!</p>
```

See [Internationalization](/docs/syntax/i18n/) for wiring up a `MessageSource`.

## String literals – `'...'`

Single-quoted text is a literal string:

```html
<span tl:text="'Hello, world'">placeholder</span>
```

## Other literals

Integers (`42`), decimals (`3.14`), `true`, `false` and `null` are literals too.
Parentheses group a sub-expression, and a leading `-` negates a number:

```html
<span tl:text="(${price} + 5) * -1">total</span>
```

## Literal substitution – `|...|`

Pipe-delimited text is a template string that interpolates embedded `${...}`
expressions, so you avoid manual concatenation:

```html
<span tl:text="|Hello, ${name}!|">greeting</span>
```

## Arithmetic

Numeric expressions support `+`, `-`, `*`, `/`, and `%`:

```html
<span tl:text="${price} * ${quantity}">total</span>
```

## String concatenation – `+`

The `+` operator concatenates strings (mixing in literals as needed):

```html
<span tl:text="${first} + ' ' + ${last}">full name</span>
```

## Ternary – `? :`

A conditional expression chooses between two values:

```html
<span tl:text="${active} ? 'Online' : 'Offline'">status</span>
```

## Elvis – `?:`

The Elvis operator supplies a default when the left side is null:

```html
<span tl:text="${nickname} ?: 'Anonymous'">name</span>
```

## Comparisons

Compare two values with `==`, `!=`, `<`, `>`, `<=`, or `>=`:

```html
<div tl:if="${score} >= ${passMark}">Passed</div>
```

Each operator also has a word-form alias, useful where symbols are awkward:
`eq` (`==`), `ne` (`!=`), `gt` (`>`), `lt` (`<`), `ge` (`>=`), `le` (`<=`).

```html
<div tl:if="${score} ge ${passMark}">Passed</div>
```

## Boolean logic

Combine boolean expressions with `and`, `or`, and `not` (or `!`):

```html
<div tl:if="${loggedIn} and not ${banned}">Welcome</div>
```

## Filters – `| name`

A filter transforms a value using pipe syntax, and filters chain left to right:

```html
<span tl:text="${name | upper}">NAME</span>
<span tl:text="${input | trim | lower}">cleaned</span>
```

Built-in filters: `upper`, `lower`, `trim`, `length`.

Filters take arguments with colon-separated syntax. Argument types include
single-quoted strings, ints, doubles, bools, null, and bare identifiers:

```html
<span tl:text="${price | currency:'USD':2}">price</span>
<span tl:text="${text | truncate:100}">long text</span>
```

Register custom filters when constructing the engine. A filter that takes
arguments receives them as a list in its second parameter. Make that parameter
optional so the filter also works without arguments:

```dart
Trellis(filters: {
  'currency': (dynamic v, [List<dynamic>? args]) {
    final code = args != null && args.isNotEmpty ? args[0] as String : 'USD';
    final digits = args != null && args.length > 1 ? args[1] as int : 2;
    return '$code ${(v as num).toStringAsFixed(digits)}';
  },
  'truncate': (dynamic v, [List<dynamic>? args]) {
    final limit = args != null && args.isNotEmpty ? args[0] as int : 80;
    final s = v.toString();
    return s.length <= limit ? s : '${s.substring(0, limit)}…';
  },
});
```

A filter declared with only the value parameter, such as `(v) => ...`, throws
"does not accept arguments" when a template passes it any.

## Utility objects – `${#...}`

Built-in utility objects expose common helpers for strings, numbers, dates, and
lists:

```html
<span tl:text="${#strings.capitalize(name)}">Name</span>
<span tl:text="${#lists.size(items)}">count</span>
```

The available objects are `${#strings.*}`, `${#numbers.*}`, `${#dates.*}`, and
`${#lists.*}`.

## No-op – `_`

A bare underscore as the **whole** attribute value means "do nothing" – the
directive is skipped and the prototype content or attribute stays:

```html
<p tl:text="_">Prototype text, kept as written</p>
```

`_` is a no-op only as the entire value. Inside an expression it is an ordinary
(undefined) variable: null in lenient mode, an error in strict mode. To set an
attribute only sometimes, return `null`, which removes it:

```html
<a tl:attr="aria-current=${isActive} ? 'page' : null">Link</a>
```

## Quick reference

| Form | Example | Meaning |
|---|---|---|
| Variable | `${user.name}` | Read from context, dot-notation, null-safe |
| Dynamic index | `${list[index]}` | List/map access with an expression index |
| Selection | `*{field}` | Field of the `tl:object` context |
| URL | `@{/users(id=${id})}` | URL with query parameters |
| Message | `#{welcome.title}` | i18n key lookup via `MessageSource` |
| String literal | `'hello'` | Single-quoted string |
| Other literals | `42` `3.14` `true` `null` | Number, boolean and null literals |
| Literal substitution | `\|Hi, ${name}!\|` | Pipe-delimited interpolated string |
| Arithmetic | `${a} + ${b}` (`- * / %`) | Numeric arithmetic |
| Concatenation | `${a} + ' ' + ${b}` | String concatenation |
| Ternary | `${c} ? 'a' : 'b'` | Conditional value |
| Elvis | `${v} ?: 'default'` | Null-coalescing |
| Comparison | `${a} == ${b}` (`!= < > <= >=`) | Value comparison |
| Comparison alias | `gt lt ge le eq ne` | Word-form comparison operators |
| Boolean | `${a} and ${b}` (`or`, `not` / `!`) | Logical operators |
| Filter | `${name \| upper}` | Pipe-based value transformation |
| Utility object | `${#strings.capitalize(x)}` | Built-in string/number/date/list helpers |
| No-op | `_` | As the whole attribute value: skip the directive |
