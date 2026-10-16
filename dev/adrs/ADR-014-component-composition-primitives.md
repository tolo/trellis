# ADR-014: Component Composition Primitives

## Status

Accepted (2026-10-15; proposed 2026-08-18). Amended at acceptance after an engine
re-verification (ledger AC-01…AC-15 in the private specs repo): prefix-named spread
keys throw (§2), extra rest-position arguments throw, parameterised fragments render
top-level by bare name, and a `tl:insert` host keeps its own directive results (§3),
slot collection and bare caller markers are pinned (§1), and Consequences and
Implementation Notes are corrected. Design pass for PB-012 (Stage 1 of the
composition-primitives PRD); implementation lands in 0.13 under the standard plan/FIS
flow. Prerequisite for the ADR-012 first component slice. Amended 2026-10-16: a
`tl:slot` in an inner invocation host's unmarked content inside a definition throws
instead of declaring a region (§1), and the forwarding open item is decided as
explicit re-marking only.

## Context

Trellis fragments accept expression parameters (`card(title, body)`) and cross-file
inclusion, but lack the three primitives that turn a fragment into a component:

1. **Content slots** – no way to pass arbitrary markup into a fragment invocation.
2. **Attribute spreading** – no way to expand a map of attributes onto an element.
3. **Attribute pass-through** – no way to forward undeclared attributes from an
   invocation to the component's markup.

Thymeleaf shares these exact gaps: its ecosystem never produced an adopted component
library, and the 2026 attempt that got furthest (Deblauwe's component-library
series) required a custom dialect with three custom processors, with the slot
implementation described as "quite complex". Trellis controls its engine and can fix
the core instead – ADR-012 makes these primitives a prerequisite for any Tier 1
component, so the UI suite consumes core features rather than workarounds. Verified
missing 2026-08-15 against
[`fragment_processor.dart`](../../packages/trellis/lib/src/processors/fragment_processor.dart)
and [`attr_processor.dart`](../../packages/trellis/lib/src/processors/attr_processor.dart).

Constraints (per the PRD and the engine's design decisions): natural-template
survival – templates stay valid HTML that renders sensibly opened directly in a
browser; AOT-safe, no reflection, no new dependencies; fits the existing processing
priority order without changing current semantics; the existing test suite passes
unchanged.

Engine facts that shape the design (see
[template-engine.md](../architecture/template-engine.md)):

- `tl:insert` replaces the host element's children and `tl:replace` discards the
  host entirely – host children are today a browser-preview placeholder, pinned by
  the shipped test suite. That discarded markup is the natural carrier for slot
  content; its semantics must stay identical when no slots are declared.
- Fragment parameters *augment* the caller context (`_bindArgs`); fragments are not
  isolated scopes. Slot scoping must follow the same model.
- The HTML5 parser mutates malformed input before any processor runs: unknown
  elements inside `<table>`/`<select>` are foster-parented out, and duplicate
  attributes are dropped at tokenization. New syntax must not create either trap.
- `tl:attr` values are `name=${expr}` binding lists via `parseBindings()`; a
  map-valued spread cannot be grafted onto that grammar unambiguously.

## Decision

All three primitives land in `trellis` core as attribute-based syntax on real HTML
elements – no new elements, no new expression grammar, no new priority slots.

### 1. Content slots – `tl:slot` attribute-marked regions

**Definition side**: inside a fragment, any element may carry `tl:slot="name"`; a
bare `tl:slot` marks the single anonymous (default) slot. The element's children are
the fallback content. When the slot is filled, the element is preserved and only its
children are replaced – the same merge rule as `tl:define` block override. Declared
regions are collected without recursing into a matched region (the `tl:define`
collection rule), so a `tl:slot` inside another region's fallback content is part of
that fallback, not a second declaration.

**Caller side**: direct children of the element carrying `tl:insert`/`tl:replace`
provide slot content. A direct child with `tl:slot="name"` fills the named slot; its
children move into the slot and the marker element itself is discarded (again the
`tl:define` rule – use `<tl:block tl:slot="name">` for wrapper-free multi-element
content, outside tables). Markers must be *literal* direct children: a plain
`<tl:block>` grouping wrapper is not looked through (its contents count as unmarked
content), and on a page, markers nested deeper are inert and draw a
`TemplateValidator` warning; inside a fragment definition they throw (see Errors).
Unmarked children fill the anonymous slot **only if the fragment declares
one**; otherwise they are discarded exactly as today, preserving the existing
placeholder idiom and the current test suite. Whitespace-only text nodes never count
as unmarked children – a pretty-printed invocation filling only named slots keeps
the anonymous slot's fallback. Multiple markers for the same slot concatenate in
document order. A bare caller-side `tl:slot` marker targets the anonymous slot
explicitly and, being a marker, throws the unknown-slot error when the fragment
declares none, unlike unmarked children, which are discarded.

**Control attributes on markers**: `tl:if`/`tl:unless` on a caller-side marker are
evaluated at graft time in the same scope as the slot content (the fragment's
effective context) and gate the contribution – falsy means the marker contributes
nothing, and the slot keeps its fallback if no other marker fills it. Any other
`tl:*` attribute on a marker throws `TemplateException` in this version (`tl:each`
replication over markers is an open item below); silently dropping them would be an
authoring trap.

**Scope**: slot content is grafted into the fragment clone at resolution time and
processed as part of the fragment's subtree, so it sees the fragment's effective
context – caller variables plus fragment parameters and locals. This is consistent
with the existing augment-not-isolate fragment scoping, and it makes scoped slots
work for free: a `tl:slot` inside a fragment's `tl:each` exposes the loop variable
to caller-supplied row markup (needed for the table component).

**Errors**: a caller marker naming a slot the fragment doesn't declare throws
`TemplateException` (new syntax, so erroring is compatibility-safe); duplicate slot
names within one fragment definition likewise; `tl:slot` on the element carrying
`tl:fragment` itself likewise – the fragment root is the component boundary, and a
root-level slot would collide with the documented fragment-root processing traps
(declare the region on an inner element instead). Inside a definition, a `tl:slot`
in the *unmarked* content of an inner `tl:insert`/`tl:replace` host (the fragment root
counts as a host when it carries one) throws `TemplateException` at invocation of the
enclosing fragment: it can neither fill that invocation's slot (it is not a direct
child) nor declare a slot of the enclosing fragment without guessing between the two.
The error fires whether or not the caller fills the slot and even when the inner
invocation is gated off by `tl:if`, and it names the marker, the host directive and the
fragment. A nested host inside that content starts over for its own children, and a
nested `tl:fragment` owns its own slots. To forward a slot, re-mark it explicitly
inside a direct-child marker (`<tl:block tl:slot>` for the anonymous slot). A `tl:slot`
outside any fragment definition or invocation is inert – the attribute is stripped,
the default content remains (graceful degradation, including direct
`renderFragment()` calls).

**Scope of invocation forms**: slots (and the rest parameter below) work through
*name-based* fragment invocation only – CSS-selector and tag-name fragment
targeting (`~{file :: #id}`) has never bound parameters and keeps its current
semantics unchanged; caller markers on a selector invocation therefore throw the
unknown-slot error.

### 2. Attribute spreading – `tl:attrs="${map}"`

A new first step inside the existing `AttrProcessor` group, not a registered
processor, which could not order itself within its own priority slot. The value is a
single expression
evaluating to a `Map`; `null` is a no-op, and any other non-`Map` value throws
`TemplateException`. Merge rules:

- Spread runs **first** within the attribute group, so the element's explicit
  `tl:*` attribute directives (shorthands, `tl:classappend`/`tl:styleappend`,
  `tl:attr`) override spread entries.
- Against literal attributes, spread entries **overwrite** – except `class` and
  `style`, which **append** (the component case is "add classes/`hx-*` to what the
  component already has"; appending mirrors Vue's merge rule, and `tl:class` remains
  the explicit full-replace escape hatch).
- Values go through the same `_setAttribute` semantics as `tl:attr`: `null` removes
  the attribute, boolean-attribute names render valueless/removed for `true`/`false`.
- Attribute **names** are the new injection surface – and a categorically new
  capability: everywhere else in the engine, including `tl:attr`, the attribute
  name is literal in the template source and only the value is dynamic; `tl:attrs`
  is the first mechanism where the name itself is runtime-determined. Names must
  match `^[A-Za-z][A-Za-z0-9_:.-]*$`, anything else throws `TemplateException`.
  Keys beginning with the engine's configured attribute prefix (`tl:` by default,
  compared case-insensitively) also throw. The engine re-reads an element's
  attributes on every processor pass, so a spread key such as `tl:attr` or
  `tl:remove` would execute as a directive: in the same attribute-group pass, by
  `tl:remove` at `afterAttributes`, or by a custom processor at `lowest`. Keys for
  already-passed slots would be stripped silently. Rejecting the prefix keeps the
  spread map a data surface only.
  Lowercase names are the recommended authoring convention (HTML5 parsers lowercase
  attribute names on re-parse, so `data-myFoo` never reaches `dataset.myFoo`
  client-side – a pre-existing HTML fact, documented rather than validated, because
  spread keys exist only at runtime). Values are serializer-escaped exactly like `tl:attr`
  values today. `on*` names stay allowed: the map is developer-supplied server-side
  data, and `tl:attr` can already set an `on*` value dynamically under a literal
  name.
- One `tl:attrs` per element (the HTML5 tokenizer drops duplicate attributes before
  the engine ever runs – same constraint as `tl:attr`).

### 3. Attribute pass-through – `...rest` fragment parameter

A fragment opts in by declaring a rest parameter – at most one, and it must be
last; a duplicate or non-final rest parameter throws `TemplateException` when the
fragment definition is collected:

```html
<label tl:fragment="field(label, name, ...attrs)">
```

An invocation that supplies more positional arguments than the declared non-rest
parameters throws `TemplateException`; fragments without a rest parameter keep
ignoring extra arguments as today.

At invocation, the engine binds it to a map of the invoking element's **effective
attribute set**: its literal non-`tl:*` attributes plus its own attribute-group
directives (`tl:attrs`, `tl:attr`, shorthands, appends: the whole attribute group, in
its normal merge order) evaluated once in caller scope – minus
all `tl:*` control attributes. The fragment places them wherever it wants via
spreading (`tl:attrs="${attrs}"`) – on the root, on an inner `<input>`, anywhere.
`hx-*` and `data-*` entries flow through as opaque strings (the core stays
hypermedia-agnostic per ADR-011); valueless boolean attributes arrive as `''` and
re-render valueless. The map is empty for `renderFragment()` calls and hosts with no
forwardable attributes. `renderFragment()` and `renderFragments()` address a
parameterised fragment by its bare name: its declared parameters resolve from the
same-named context keys, and a rest parameter is bound to an empty map. A fragment
name with arguments in parentheses throws `TemplateException`; an empty `()` is read
as the bare name. Fragments without a rest parameter are unaffected by pass-through –
it is opt-in, so no reserved variable name exists and no existing template changes
behavior.

Pass-through is meaningful chiefly with `tl:replace` (where host attributes are
otherwise lost). With `tl:insert` the map is bound identically: the host's own
attribute directives are applied to it and forwarded, the rule its literal attributes
already follow, so spreading the map duplicates attributes already on the surviving
host – documentation steers component invocation to `tl:replace`.

### Priority-order fit

No existing processor moves and no new slot is added: slot grafting and rest-param
binding happen inside fragment resolution (`InsertProcessor`/`ReplaceProcessor`,
`afterIteration`), and `tl:attrs` joins the `AttrProcessor` group (`afterContent`
enum slot). `tl:slot` itself is **not** a registered `Processor` and holds no
priority slot – it is structural, like `tl:fragment` collection: caller-side
markers are consumed by a scan of the host's direct children during invocation
resolution, definition-side regions are resolved by the graft step before
`processFragmentContent` runs, and any remaining `tl:slot` attribute is removed by
the generic `tl:*` cleanup. The depth limit, the registry stack, and the
`FragmentHost` interface
([`processor_api.dart`](../../packages/trellis/lib/src/processor_api.dart)) are
unchanged. Fragment cycle detection is also unchanged – with one disclosed
interaction: it is keyed on fragment *name*, so invoking a fragment inside its own
slot content (card-in-card) trips the existing cycle error even though the nesting
is author-bounded; see the open item below.

### Tier-1 example (field + dialog, end-to-end)

Component file (`ui/components.html`) – valid HTML, renders its defaults as a
browser prototype:

```html
<label tl:fragment="field(label, name, ...attrs)" class="trellis-field">
  <span class="trellis-field-label" tl:text="${label}">Label</span>
  <input class="trellis-field-input" type="text" tl:attr="name=${name}" tl:attrs="${attrs}">
  <span class="trellis-field-hint" tl:slot="hint"></span>
</label>

<dialog tl:fragment="dialog(id, title, ...attrs)" class="trellis-dialog"
        tl:id="${id}" tl:attrs="${attrs}">
  <header><h2 tl:text="${title}">Title</h2></header>
  <div class="trellis-dialog-body" tl:slot>Body</div>
  <footer tl:slot="footer"><button>Close</button></footer>
</dialog>
```

Application template – also valid HTML; the placeholder content shows in a browser:

```html
<div tl:replace="~{ui/components.html :: field('Email', 'email')}"
     type="email" required hx-post="/validate" hx-trigger="blur">
  <span tl:slot="hint">We never share your email.</span>
</div>

<div tl:replace="~{ui/components.html :: dialog('confirm', 'Delete item?')}">
  <p>This action cannot be undone.</p>
  <tl:block tl:slot="footer">
    <button class="trellis-button-danger" tl:attr="hx-delete=@{/items(id=${item.id})}">Delete</button>
    <button>Cancel</button>
  </tl:block>
</div>
```

Rendered field: `type="email"`, `required`, and the `hx-*` attributes land on the
`<input>` via `...attrs` + `tl:attrs` (spread overwrites the literal `type="text"`);
the hint slot's fallback is replaced by the caller's text inside the fragment's
styled `<span>`. Coverage of the remaining ADR-012 candidates is tiered honestly:
field and dialog are **demonstrated** above; table is **traced by mechanism** (a
`tl:slot` row region inside the fragment's `tl:each` – the grafted content is
cloned per iteration and sees the loop variable, verified against `EachProcessor`'s
clone-then-process flow); dropdown, combobox, and toast are **expected by shape
analogy** (dropdown/toast are dialog-shaped, combobox is field-shaped) and must be
proven with worked fragments in Stage 2 before the prerequisite is declared
satisfied.

## Consequences

### Positive

- Every Trellis user gets component composition in core, independent of the UI
  suite; the demonstrated Tier 1 candidates become thin fragment files with no
  custom processors.
- Zero behavioral change to existing templates: all three primitives are new
  attributes/syntax that existing templates don't contain, and the one shared code
  path (invocation-host children) keeps its discard semantics unless a fragment
  declares a slot.
- Natural templates survive end-to-end: both component and application files above
  open as sensible HTML prototypes; no new element means no new foster-parenting
  trap; definition-side regions work on `<tr>`/`<option>` because they already sit in
  table/select context. Caller-side markers must be elements the HTML5 parser accepts
  as children of the invocation host (`<tr>`/`<td>` only when the host sits inside a
  real `<table>`, `<option>` under `<select>`, `<span>`/`<tl:block>` otherwise). The
  parser reshapes anything else before the engine runs, so this is an authoring rule,
  not a runtime check.
- Slot semantics reuse the already-shipped `tl:define` merge mental model; spreading
  and pass-through converge on one mechanism (`tl:attrs`).
- No new dependencies, no reflection, pure DOM + map operations – AOT-safe.

### Negative

- Slot content sees the fragment's merged scope, so a fragment parameter shadows a
  same-named caller variable inside slot content. Inherent to the existing
  augment-not-isolate context model; documented rather than prevented.
- Dynamic attribute names (spread map keys) are a net-new template-injection
  surface with no `tl:attr` analogue, mitigated by name validation (shape regex plus
  rejection of prefix-named keys) and serializer escaping; for attribute *values*
  the trust boundary matches `tl:attr` (a hostile developer-supplied map can still
  set `on*` handlers).
- Nesting a component inside its own slot content trips the name-keyed fragment
  cycle error in this version (open item below).
- `slot` and `attrs` join the built-in `tl:*` attribute namespace: a custom dialect
  already registering either name will double-fire silently: the conflict warning
  compares `Processor.attribute` values only, and neither name (nor `classappend`,
  `styleappend`, or the shorthands) is processor-backed. Extending that check is a
  small follow-up outside this ADR.
- One API behavior change: `renderFragment()`/`renderFragments()` throw on a fragment
  name with arguments in parentheses, where they previously returned the definition
  unprocessed. An empty `()` keeps resolving. The release CHANGELOG states it.
- Strict mode makes the rest map unprobeable: `${attrs.type} ?: 'text'` throws on an
  absent key before the elvis applies, and filters are unary. Components spread the
  whole map and carry defaults as literal attributes the spread overwrites; a
  key-probing helper is a separate ergonomic question.
- `<tl:block tl:slot>` inherits the known `<tl:block>` table foster-parenting trap;
  the mitigation is the same documented rule (mark a real element instead).
- The `tl:define`-style "marker element is discarded, children move" rule is a
  learning bump for developers expecting web-component `<slot>` semantics where the
  filler element itself is projected.

### Neutral

- Fragment arguments remain positional; named arguments are a separate ergonomic
  question, out of scope here.
- The rest parameter is engine-bound but author-named, so it is ordinary context
  data – inspectable, spreadable in parts, or ignorable.

## Alternatives Considered

Full matrices in the [research digest](research/ADR-014-research.md).

1. **Thymeleaf-style markup-as-fragment-argument** (`~{...}` passed as a parameter)
   – rejected: markup inside attribute values defeats natural templates, needs new
   expression grammar, and is the empirically documented failure mode (custom
   dialect, manual nesting-depth tracking) this ADR exists to avoid.
2. **Named slot elements** (`<tl:slot name="x">`) – rejected: an unknown element
   inside `<table>`/`<select>` is foster-parented out by the HTML5 parser (the
   documented `<tl:block>` trap), and the table component needs slots on `<tr>`.
   Attribute-marked regions get the same expressiveness with none of the parser
   risk.
3. **Single anonymous body slot only** – rejected: cannot express dialog
   (body + footer) or field (hint); fails the ADR-012 candidate list outright.
4. **Extending `tl:attr` to accept a map** – rejected: a bare `tl:attr="${map}"`
   hard-fails today (`parseBindings()` throws on a segment without `=`), so the
   overload would be backward-compatible – but it puts two grammars (binding list
   vs. map expression) under one attribute, distinguishable only by parse-failure
   shape, and the tokenizer's one-attribute-per-name rule means spread and explicit
   bindings could never coexist on the same element.
5. **Automatic attribute forwarding on `tl:replace`** – rejected: silently changes
   the rendered output of existing templates whose host placeholders carry
   attributes, and gives the fragment author no control over which element receives
   them.
6. **Reserved implicit `${attrs}` variable in every fragment** – rejected:
   unconditionally shadows user context named `attrs`; the declared rest parameter
   is opt-in and author-named, eliminating the collision class.
7. **Distinct caller-side fill attribute** (e.g. `tl:fill="name"` instead of
   `tl:slot` on both sides) – rejected on parsimony, not evidence: it removes the
   both-sides overload, but the direct-children binding rule is required regardless
   to bind content to the right invocation, so it adds a vocabulary item without
   removing the structural rule. Revisit if the shared name proves confusing in
   practice.

## Implementation Notes

For the Stage 2 plan/FIS (not binding on internals, binding on semantics):

- Fragment registry entries stay `(Element, List<String>)`: the record type is part
  of `FragmentHost`'s signature. The rest parameter travels as the literal `...name`
  last entry of `paramNames`; declared slot names are derived by scanning the
  resolved fragment element at invocation (same-file lookups read the pre-processing
  clone stored by `collectFragments`, cross-file lookups a fresh parse).
  Rest-placement errors surface at definition collection; slot declaration errors
  (duplicate, root-level) at invocation, so an uninvoked malformed definition does
  not throw.
- Host effective-attribute capture runs the attribute group (including `tl:attrs`)
  once on the host itself at resolution time, harvests the resulting non-`tl:*`
  attributes into the map, then strips the consumed directives so they cannot re-fire
  at `afterContent`. A surviving `tl:insert` host therefore renders with its own
  directive results and forwards them; a `tl:replace` host is discarded, so one code
  path serves both. Note this is new behavior, not a relocation: on a `tl:replace`
  host today, attribute directives never fire at all (`ReplaceProcessor` returns
  false before the attribute group runs), so capture must activate only for
  rest-parameter fragments – a `tl:replace` invocation of a fragment without
  `...rest` keeps today's silently-inert host directives.
- Slot grafting for cross-file fragments happens after the external registry push;
  a same-file fragment reference inside slot content therefore resolves
  innermost-registry-first (included file wins on a name collision). Accepted
  default; revisit only on real-world confusion.
- `TemplateValidator`: report `tl:slot` markers under a visible invocation host that
  are not its literal direct children: a warning on a page, where they are inert, and
  an error inside a definition, mirroring the engine's wrapped-marker message (a
  marker inside a direct-child marker re-marks a region and stays clean). Also warn
  on a literal `id` on or inside a parameterized fragment definition (parameterless
  fragments are the HTMX swap-target idiom: 15 fragment/id pairs across `examples/`
  and `themes/` today, all parameterless). `<tl:block tl:slot>` in table context is
  already covered by the shipped foster-parenting warning, so no second check.
  Mixed-case spread keys are not statically decidable (the expression grammar has no
  map literal), so documentation only.
- Tests must map to this ADR's scenarios: slot fill/fallback/anonymous/error cases,
  scoped slot inside `tl:each`, spread merge/override/boolean/null/name-validation
  (prefix-key rejection included), pass-through with
  `tl:replace`/`tl:insert`/`renderFragment()`, bare-name top-level rendering, cross-file
  variants, strict mode, and the pinned placeholder-discard behavior.
- Update [template-engine.md](../architecture/template-engine.md) (fragment system,
  processor table) as part of implementation, per the architecture-maintenance
  rule. Its Built-in Processors priority table was corrected against the
  `ProcessorPriority` enum in `0bb00bd` (text/utext/inline are `afterInclusion`,
  `tl:attr` is `afterContent`, `tl:remove` is `afterAttributes`); verify it against
  the enum again, then extend it.

### Open items (defaults stated)

- **Named fragment arguments** (`field(label='X')`): default – stay positional;
  reconsider if component invocations grow long parameter lists.
- **Forwarding slot content through nested components**: decided – explicit
  re-marking only; a `tl:slot` marker binds to its nearest enclosing invocation host
  (direct-children rule), and the wrapped case (a marker in an inner host's unmarked
  content) throws rather than forwarding implicitly (§1 Errors).
- **Duplicate caller markers for one slot**: default – concatenate in document
  order.
- **Self-nesting a fragment via its own slot content**: default – the name-keyed
  cycle error stands in this version. Preferred revisit if nested-component demand
  appears (trees, accordions): exempt grafted slot-content subtrees from the
  inclusion-stack check – they are author-bounded – keeping `maxFragmentDepth` as
  the backstop.
- **`tl:each` on a caller-side slot marker** (replicated contributions): default –
  throws in this version, per the control-attribute rule above; revisit with
  concrete demand.
- **Dynamic pass-through beyond the attribute group** (e.g. computing the whole
  forwarded map on the host): default – compose in the context and use `tl:attrs`
  directly on the fragment side; no extra host syntax.

## Project Compliance

- **Natural templates / AOT / minimal-deps core design decisions** – all three
  primitives are attributes on valid HTML, implemented with DOM and map operations
  only.
- **ADR-004** – the primitives are general core capabilities; core gains no UI or
  component awareness.
- **ADR-011** – the core stays hypermedia-agnostic: `hx-*` attributes pass through
  spreading/pass-through as opaque strings, never interpreted.
- **ADR-012** – addresses the declared prerequisite: field and dialog are
  demonstrated as plain fragments over these primitives, table is traced by
  mechanism, and the remaining candidates are verified during Stage 2.
- **Processing-priority contract** – no existing processor moves; new work attaches
  to existing slots (`afterIteration` resolution, `afterContent` attribute group).

## References

- [Research digest](research/ADR-014-research.md) – options, weighted matrices,
  assumption log.
- PB-012 composition-primitives PRD (private specs repo) – problem statement,
  constraints, stages.
- [`fragment_processor.dart`](../../packages/trellis/lib/src/processors/fragment_processor.dart),
  [`attr_processor.dart`](../../packages/trellis/lib/src/processors/attr_processor.dart),
  [`processor.dart`](../../packages/trellis/lib/src/processor.dart),
  [`processor_api.dart`](../../packages/trellis/lib/src/processor_api.dart) –
  current mechanics the design extends.
- [Template engine architecture](../architecture/template-engine.md) – pipeline,
  priority model, fragment system.
- [ADR-012](ADR-012-trellis-ui-contract.md) – the consumer of these primitives.
- Deblauwe, *Writing a Thymeleaf component library* (2026-07-27, parts 2–3):
  https://www.wimdeblauwe.com/blog/2026/07/27/writing-a-thymeleaf-component-library/
- Prior art: [Vue slots](https://vuejs.org/guide/components/slots.html),
  [Vue fallthrough attributes](https://vuejs.org/guide/components/attrs.html),
  [HTML `<slot>`](https://developer.mozilla.org/en-US/docs/Web/HTML/Element/slot),
  [Thymeleaf fragment expressions](https://www.thymeleaf.org/doc/tutorials/3.1/usingthymeleaf.html#template-layout).
