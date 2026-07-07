---
title: Syntax Reference
description: Every tl:* attribute, the <tl:block> element, and every expression form the Trellis engine supports – each with a worked example.
weight: 20
---

This is the complete reference for the Trellis template language. It documents
every `tl:*` attribute the engine ships with, the `<tl:block>` virtual element,
and every expression form you can write inside an attribute.

If you are new to Trellis, read [Getting Started](/docs/getting-started/) first,
then come back here to look things up.

## Expression language

The value of nearly every `tl:*` attribute is an *expression*. Learn the
expression syntax once and it applies everywhere.

- [**Expressions**](/docs/syntax/expressions/) – variables `${...}`, selection
  `*{...}`, URLs `@{...}`, messages `#{...}`, literals, arithmetic, ternary,
  Elvis, comparisons, boolean logic, filters, utility objects, and the no-op.

## Attributes by group

- [**Text**](/docs/syntax/text/) – `tl:text`, `tl:utext`.
- [**Conditionals**](/docs/syntax/conditionals/) – `tl:if`, `tl:unless`,
  `tl:switch`, `tl:case`.
- [**Iteration**](/docs/syntax/iteration/) – `tl:each` and its status variables.
- [**Attributes**](/docs/syntax/attributes/) – `tl:attr`, `tl:href`, `tl:src`,
  `tl:value`, `tl:class`, `tl:id`, `tl:classappend`, `tl:styleappend`.
- [**Fragments**](/docs/syntax/fragments/) – `tl:fragment`, `tl:insert`,
  `tl:replace`.
- [**Template inheritance**](/docs/syntax/inheritance/) – `tl:extends`,
  `tl:define`.
- [**Local variables & selection**](/docs/syntax/local-variables/) – `tl:with`,
  `tl:object`.
- [**Inline processing**](/docs/syntax/inline/) – `tl:inline`.
- [**Output control**](/docs/syntax/output-control/) – `tl:remove` and the
  `<tl:block>` virtual element.
- [**Internationalization**](/docs/syntax/i18n/) – `#{...}` message expressions.

## Processing order

When several attributes appear on one element, the engine applies them in a
fixed priority order, highest first:

1. `tl:with` – bind local variables
2. `tl:object` – set the selection context
3. `tl:if` / `tl:unless` – conditionals
4. `tl:switch` / `tl:case` – multi-branch conditionals
5. `tl:each` – iteration
6. `tl:insert` / `tl:replace` – fragment inclusion
7. `tl:text` / `tl:utext` – content
8. `tl:attr` and the attribute shorthands – attribute mutation

Understanding this order explains, for example, why `tl:if` on the same element
as `tl:each` is evaluated before the loop runs.
