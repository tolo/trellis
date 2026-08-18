# ADR-014 Research Digest – Component Composition Primitives

Distilled trade-off analysis behind [ADR-014](../ADR-014-component-composition-primitives.md).
Produced 2026-08-18 in an unattended design pass; gate answers below are recorded
assumptions, not user confirmations.

## Decision Context *(assumed)*

- **Core question**: what syntax and semantics should content slots, attribute
  spreading, and attribute pass-through have in `trellis` core?
- **Constraints** (from the PB-012 PRD and CLAUDE.md design decisions):
  natural-template survival (templates stay valid HTML and render sensibly opened
  directly in a browser); AOT-safe, no reflection, no new dependencies; fits the
  existing processing priority order without changing current semantics; existing
  test suite passes unchanged.
- **Success criterion**: the six ADR-012 Tier-1 candidates (field, dialog,
  dropdown, combobox, table, toast) expressible as plain fragments without custom
  processors.
- **Dealbreakers**: any behavior change to existing `tl:insert`/`tl:replace`/
  `tl:attr` semantics; any new element that triggers HTML5 foster-parenting inside
  `<table>`/`<select>`; any raw string re-parse that widens the injection surface.

## Criteria + Weights *(assumed)*

| # | Criterion | Weight | Why |
|---|---|---|---|
| C1 | Natural-template survival | 25% | Founding design decision; dealbreaker-adjacent |
| C2 | Backward compatibility / existing-semantics fit | 20% | Hard PRD constraint |
| C3 | Component expressiveness (Tier-1 coverage) | 20% | The reason the primitives exist |
| C4 | Escaping / injection surface | 15% | Spreading introduces dynamic attribute *names* |
| C5 | Pipeline fit + implementation simplicity | 10% | AOT, no deps, priority order untouched |
| C6 | Ergonomics / prior-art familiarity | 10% | Vue/web-components conventions lower learning cost |

## Options and Scores

Scores 1–5 per criterion; weighted total in the last column.

### Slots

| Option | C1 | C2 | C3 | C4 | C5 | C6 | Total |
|---|---|---|---|---|---|---|---|
| S1 Thymeleaf-style markup-as-fragment-argument (`~{...}` passed as arg) | 2 | 4 | 3 | 4 | 2 | 2 | 2.90 |
| S2 Named slot **elements** (`<tl:slot name="x">`) | 2 | 4 | 5 | 5 | 3 | 4 | 3.75 |
| **S3 Attribute-marked regions (`tl:slot="x"` on real elements, both sides)** | **5** | **5** | **5** | **5** | **4** | **4** | **4.80** |
| S4 Body = single anonymous slot only | 5 | 4 | 2 | 5 | 5 | 3 | 4.00 |

- **S1** is what Thymeleaf actually has, and it is the documented failure: the 2026
  Deblauwe component-library series needed a custom dialect with manual
  nesting-depth tracking to make it usable ("quite complex"). Markup stuffed into an
  attribute value is not browser-renderable (C1) and needs new expression grammar (C5).
- **S2** fails C1 structurally: an unknown `<tl:slot>` element inside `<table>` /
  `<select>` is foster-parented out by the HTML5 parser – the exact trap already
  documented for `<tl:block>` in LEARNINGS ("in table" insertion mode,
  `unexpected-start-tag-implies-table-voodoo`). A slot on `<tr>` is a real Tier-1
  need (table component), so this is not an edge case. Also needs self-closing
  normalization and unwrap logic.
- **S3** leads on total and ties-or-wins every criterion except C5 (S4 is simpler): real elements carry the marker, so tables work, the
  browser renders default content as the prototype, and the semantics mirror the
  existing `tl:define` block merge ("parent element preserved, only children
  replaced" – inheritance.dart). Same attribute on both sides mirrors `tl:define`
  (both parent and child use the same attribute), disambiguated structurally.
  A variant with a **distinct caller-side attribute** (e.g. `tl:fill="name"`) was
  considered but not separately scored: it removes the both-sides overload, but the
  direct-children binding rule is needed regardless (to bind content to the right
  invocation), so it buys no structural simplification while adding a second
  vocabulary item. This is a parsimony call, not an evidenced trade-off
  (filter verdict R2: downgraded).
- **S4** cannot express dialog (body + footer) or field (hint) – fails the Tier-1
  criterion outright; kept only as the degenerate case inside S3 (anonymous slot).

### Attribute spreading

| Option | C1 | C2 | C3 | C4 | C5 | C6 | Total |
|---|---|---|---|---|---|---|---|
| P1 Extend `tl:attr` to accept a map expression | 5 | 4 | 5 | 4 | 2 | 3 | 4.15 |
| **P2 Dedicated `tl:attrs="${map}"` processor** | **5** | **5** | **5** | **4** | **5** | **5** | **4.85** |
| P3 Expression-level filter (`${map \| spread}`) | 5 | 4 | 3 | 3 | 2 | 2 | 3.50 |

- **P1**: a bare `tl:attr="${map}"` *hard-fails* today (`parseBindings()` throws
  `Malformed binding: missing "="` on any segment without a literal `=`), so no
  existing template can carry one and overloading would be backward-compatible
  (C2 raised from the initial draft). It still loses: one attribute carrying two
  grammars (binding list vs. map expression), distinguishable only by the shape of
  a parse failure, is a worse authoring contract and error-reporting surface, and
  the single-`tl:attr`-per-element tokenizer constraint means spread and bindings
  could not coexist on one element under one attribute name.
- **P3** puts a DOM mutation inside the expression layer – filters return values,
  they don't mutate elements; wrong layer entirely.
- **P2** is one new processor in the existing `AttrProcessor` group; zero grammar
  changes, zero existing-semantics risk, matches Vue `v-bind="obj"` / JSX
  `{...props}` expectations.

### Attribute pass-through

| Option | C1 | C2 | C3 | C4 | C5 | C6 | Total |
|---|---|---|---|---|---|---|---|
| T1 Automatic forwarding to fragment root on `tl:replace` | 5 | 1 | 4 | 3 | 3 | 4 | 3.40 |
| T2 Reserved implicit variable (`${attrs}`) always bound in fragments | 5 | 3 | 5 | 4 | 4 | 4 | 4.25 |
| **T3 Declared rest-parameter `...attrs` + `tl:attrs` spread** | **5** | **5** | **5** | **4** | **4** | **4** | **4.65** |
| T4 Caller enumerates attributes to forward | 5 | 5 | 2 | 4 | 3 | 2 | 3.75 |

- **T1** is a behavior change: today `tl:replace` discards the host element's
  literal attributes, and existing templates (and the shipped test suite) rely on
  the host being a disposable placeholder. Automatic forwarding silently changes
  rendered output – dealbreaker under C2. It also gives the fragment author no say
  in *which element* receives the attributes (field wants them on the `<input>`,
  not the root).
- **T2** unconditionally shadows any user context variable named `attrs` inside
  every fragment – a silent semantic change for existing templates (C2) with no
  opt-out.
- **T3** is opt-in at the fragment definition (`tl:fragment="field(label, ...attrs)"`),
  author-named (no reserved-word collision), and composes with spreading instead of
  adding a second mechanism: pass-through *is* spreading of an engine-bound map.
  Precedent for engine-synthesized bindings: `tl:each`'s `${itemStat}`.
- **T4** defeats the purpose – the caller enumerating attributes is what `tl:attr`
  on the host already does; "undeclared attributes flow through" is the requirement.

## Cross-Cutting Semantic Decisions

1. **Slot content scope – fragment's effective context (graft-then-process).**
   Caller children are grafted into the fragment clone at resolution time, then
   processed as part of `processFragmentContent`. Trellis fragments already merge
   caller context with parameters (`_bindArgs` augments, it does not isolate), so
   slot content seeing caller variables *plus* fragment params/locals is consistent
   with existing scoping – unlike Vue, which isolates props and therefore needed
   caller-only slot scope plus a separate scoped-slots mechanism. Graft-then-process
   also gives scoped slots for free: a `tl:slot` inside a fragment's `tl:each` sees
   the loop variable, which the table component needs. Cost: a fragment parameter
   can shadow a same-named caller variable inside slot content – documented, and
   inherent to the existing merge model.
2. **Unmarked caller children fill the anonymous slot only if the fragment declares
   one; otherwise they are discarded exactly as today.** This preserves the existing
   placeholder idiom (`<div tl:insert="nav">placeholder</div>`) that the current
   test suite pins. `tl:slot`-marked children with no matching fragment slot throw
   `TemplateException` – new syntax, so erroring is compat-safe and catches typos.
3. **Spread merge rules**: spread runs first within the attribute group, so explicit
   `tl:*` attribute processors (shorthands, `classappend`, `tl:attr`) override it;
   against *literal* attributes, spread overwrites – except `class` and `style`,
   which append (Vue's merge rule; the component case is "add utility/hx classes to
   the component's own class"). `null` map → no-op; `null` value → attribute
   removed; boolean attributes reuse `_setAttribute` semantics.
4. **Attribute-name validation**: spread names must match
   `^[A-Za-z][A-Za-z0-9_:.-]*$`; anything else throws `TemplateException`. Dynamic
   attribute *names* are a categorically new capability – everywhere else in the
   engine (including `tl:attr`) the attribute name is literal in the template
   source and only the value is dynamic; `tl:attrs` is the first mechanism where
   the name itself is runtime-determined (filter verdict R7: downgraded the
   "same trust level" framing). Values are serializer-escaped like `tl:attr`
   values. `on*` names remain allowed: the map is developer-supplied server-side
   data, and blocking them was rejected as surprising while `tl:attr` can already
   set an `on*` value dynamically under a literal name.
5. **No new priority slots.** Slot grafting and `...attrs` binding happen inside
   fragment resolution (`InsertProcessor`/`ReplaceProcessor`, `afterIteration`);
   `tl:attrs` joins the `AttrProcessor` group (`afterContent` enum slot). Cycle
   detection, depth limits, and the `FragmentHost` interface are unchanged.

## Prior Art Consulted

- Thymeleaf fragment expressions (`~{}` as argument) and the 2026 Deblauwe
  component-library series (custom dialect, three custom processors) – the evidence
  that S1 is the failure mode, per the private Thymeleaf-ecosystem research
  (2026-08-15).
- Vue 3: `<slot>`/`v-slot` naming, default/fallback content, `v-bind="obj"` merge
  behavior (class/style merge), `inheritAttrs`/`$attrs`.
- Web components: `<slot name>` element model (rejected here for parser reasons,
  kept for naming familiarity).
- JSX spread and React's override-only merge (rejected for class/style).
- Trellis internals: `tl:define` block-merge semantics, `tl:each` status-variable
  binding, `tl:block` normalization traps, tokenizer duplicate-attribute drop.

## Findings-Filter Outcome (Phase 3)

Fresh-context filter pass, 2026-08-18 (run on Sonnet at xhigh – the Opus tier was
returning sustained 529s; deviation from the Opus-for-review routing noted).
**Validated**: R1 (foster-parenting rejection of `<tl:slot>` element – trap
confirmed in LEARNINGS), R3 (graft-then-process scoping – `_bindArgs` augmentation
and `EachProcessor` clone flow traced), R4 (placeholder-discard pinned by existing
tests – confirmed by grep), R5 (dedicated `tl:attrs` – found *stronger* than
drafted, `tl:attr="${map}"` hard-fails today; P1 correction above), R6 (spread
merge rules match `_processAttributesImpl` step order), R8 (`tl:replace` attribute
discard verified as the T1 compat break), R9 (priority-fit claim precise; capture
bookkeeping flagged). **Downgraded**: R2, R7, R10 – corrections applied above and
in the ADR (unscored `tl:fill` variant recorded, dynamic-name trust framing
corrected, Tier-1 coverage claim tempered to demonstrated/traced/extrapolated).
No factual errors found.

## Doc-Review Round (post-Phase 3)

A fresh-context doc-lens + critic review of the ADR (2026-08-18, Sonnet fallback
for the same reason) surfaced 20 findings; a second findings filter validated 12,
downgraded 7, withdrew 1. Applied here: seven runner-up weighted totals were
understated and are corrected above (winners unchanged; margins were overstated),
and the S3 "wins every criterion" phrase was corrected. Applied in the ADR:
explicit rules for whitespace-only children, control attributes on slot markers,
`tl:slot` on the fragment root (error), literal-direct-children (no `<tl:block>`
look-through), name-based-invocation-only scoping, non-`Map` `tl:attrs` values,
rest-parameter placement errors, the `tl:slot` structural (non-Processor)
mechanism, the name-keyed cycle-detection interaction with self-nested slots, and
the stale `template-engine.md` priority table. The ADR's Decision section is
authoritative where this digest's earlier summaries are less specific.

## Assumption Log (`--auto` gates)

- **Decision context**: taken verbatim from the PB-012 PRD Stage 1 and the tasking
  for this design pass; not user-reconfirmed.
- **Criteria + weights**: authored for this pass (table above); the ordering
  natural-templates > compatibility ≈ expressiveness > security > simplicity >
  ergonomics follows the PRD's constraint list order.
- **ADR decision**: producing ADR-014 was the explicit task; Status stays Proposed
  until the owner accepts.
