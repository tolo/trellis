# Effective Dart Guidelines

Condensed best practices from official Dart documentation. Applies to all pure Dart and Flutter projects.

**Sources**: [Effective Dart](https://dart.dev/effective-dart) (style, documentation, usage, design), [Language Tour](https://dart.dev/language), [Linter Rules](https://dart.dev/tools/linter-rules)


## Style

### Naming Conventions

| Pattern | Used for |
|---------|----------|
| `UpperCamelCase` | Classes, enums, typedefs, type parameters, extensions, mixins |
| `lowerCamelCase` | Variables, parameters, functions, methods, **constants** |
| `lowercase_with_underscores` | Packages, directories, source files, import prefixes |

- Constants use `lowerCamelCase` (not `SCREAMING_CAPS`): `const defaultTimeout = 1000;`
- Acronyms > 2 letters capitalize like words: `HttpClient`, `Uri` (not `HTTPClient`)
- Exactly 2-letter acronyms capitalize both: `ID`, `UI`, `IO`
- Don't use prefix notation (`kDefaultTimeout`) or Hungarian notation
- Don't use leading `_` for non-private identifiers (locals, params)
- Use `_` wildcard for unused callback params: `future.then((_) { ... });`

### Import Organization (in order, separated by blank lines)

1. `dart:` imports
2. `package:` imports
3. Relative imports

- Alphabetize within each section
- Use relative imports within `lib/` (between files both inside `lib/`)
- Use `package:` imports when importing `lib/` from outside `lib/` (tests, bin)
- Don't use `package:` imports within the same package's `lib/` directory

### Formatting

- Always use `dart format` — never manually format
- Line length is project-configurable (default 80; set via `dart format -l` or `analysis_options.yaml`)
- Always use curly braces for control flow (even single-line `if`/`else`)
- Use `=` default value syntax (not `:`)


## Documentation

### Doc Comments

- Use `///` for all public APIs (not `/** */` or `//`)
- Start with a brief, single-sentence summary (own paragraph)
- Separate summary from body with a blank line
- Use square bracket references: `[ClassName]`, `[methodName]`, `[paramName]`
- Write in prose — avoid verbose `@param`/`@return` tags
- Document _why_, not _what_ — skip obvious documentation
- Use backtick fences for code blocks (not 4-space indent)
- Don't document `toString()` overrides unless surprising

### When to Document

- **DO** document: public classes, members, top-level functions, typedefs, extensions
- **CONSIDER** documenting: private APIs (if complex), libraries (`library` directive)
- **DON'T** document: self-evident getters/setters, obvious constructors


## Usage

### Collections

- Use collection literals: `var points = <Point>[];` not `List<Point>()`
- Use `.isEmpty`/`.isNotEmpty` (not `.length == 0` or `.length > 0`)
- Use `whereType<T>()` to filter by type (not `where((e) => e is T).cast<T>()`)
- AVOID `forEach` with function literals — use `for` loops or `Iterable.map()` instead (tear-offs like `forEach(print)` are fine)
- Use `List.from()` when intentionally changing type; use `toList()` otherwise
- Use `spread` to merge collections: `[...a, ...b]`

### Strings

- Use adjacent string literals for concatenation (not `+`)
- Use string interpolation: `'Hello, $name'` (not `'Hello, ' + name`)
- Omit `{}` in simple interpolation: `'$name'` not `'${name}'`

### Variables & Types

- Don't explicitly initialize nullable fields/variables to `null` (Dart default-initializes nullable types; non-nullable types require definite initialization)
- Don't use `true`/`false` in equality: `if (flag)` not `if (flag == true)`
- Use type inference for local vars: `var items = <String>[]`
- Annotate types on public APIs: `String greet(String name) => ...`
- Prefer `final` for local variables that aren't reassigned
- Avoid `late` unless truly needed (no eager alternative, field initialized before use)
- Use `var` for locals; use explicit types on uninitialized or public declarations
- Don't annotate inferred parameter types in callbacks: `list.map((e) => e.length)`
- Don't redundantly type-annotate initialized locals

### Functions

- Use tear-offs instead of lambdas: `names.forEach(print)` not `names.forEach((n) => print(n))`
- Use `=>` for single-expression members (not for multi-line or `void` with no return)
- Don't create a lambda when a tear-off will do
- Avoid returning `this` for fluent chaining — use cascade `..` instead

### Null Safety

- Don't use `as` for nullable-to-non-nullable — check first, then use
- Use `??` for default values: `name ?? 'Guest'`
- Use `?.` for null-safe method calls
- Use `!` only when you're certain a value is non-null (sparingly)
- Promote nullable types with null-checks rather than casting
- Use `late` only when you can guarantee initialization before access

### Async

- **PREFER** `async`/`await` over raw `Future` APIs — more readable, better error handling
- **DON'T** use `async` when it has no useful effect (no `await`, no async errors)
- Use `Future<void>` (not `Future<Null>` or bare `Future`)
- Avoid `Completer` — use `async`/`await` instead (except low-level interop)
- Avoid `FutureOr<T>` as return type — use specific `Future<T>` or `T`

### Error Handling

- Throw `Exception` for runtime failures; `Error` for programming bugs
- Use specific `on` clauses: `on FormatException catch (e)` — avoid bare `catch`
- **DON'T** catch `Error` or its subclasses — they indicate bugs, let them propagate
- Use `rethrow` to preserve stack trace (not `throw e`)
- DON'T discard errors from `catch` without `on` clause
- Use `assert` for development-time invariant checks

### Control Flow

- Use `if` with element collections: `[if (condition) item]`
- Use `for` with element collections: `[for (var x in items) x.name]`
- Use `switch` expressions for exhaustive pattern matching (Dart 3.x)
- Prefer pattern matching over `is`/`as` chains


## Design (API Design)

### Naming

- Be consistent: use same term for same concept across API
- Avoid abbreviations (unless universally known: `i`, `id`, `ui`, `http`)
- Put the most descriptive noun last: `List<Element>`, not `ElementList`
- Boolean properties: non-imperative adjectives/verbs — `isEnabled`, `hasData`, `canClose`
- Boolean params: positive, clarifying names — `includeHidden: true` not `hidden: true`
- Methods with side effects: imperative verb — `add()`, `close()`, `refresh()`
- Methods returning values: noun phrase — `elementAt()`, `keys`, `length`
- Conversions: `toX()` for snapshot copies, `asX()` for views/wrappers

### Classes & Types

- Avoid defining single-method abstract classes — use `typedef` for function types instead
- Use `final` on classes not designed for subclassing
- Use `sealed` for exhaustive type hierarchies
- Use `base` to allow extension but prevent implementation
- Don't extend a class unless it was designed for it
- Override `hashCode` whenever you override `==` (maintain contract)
- Make `==` follow math rules: reflexive, symmetric, transitive, consistent

### Parameters

- **AVOID** positional boolean parameters — use named params for clarity
  - Bad: `connect(true)` — Good: `connect(enableTls: true)`
- Use inclusive start, exclusive end for ranges: `substring(1, 3)` means indices 1,2
- Use named params for optional args (especially booleans and multiple optionals)
- Place required positional params first
- Use `required` keyword for mandatory named params

### Type Parameters

- Single-letter mnemonics: `E` (element), `K` (key), `V` (value), `T` (type), `R` (return), `S`/`U` (additional)
- If a type parameter isn't meaningful, `T` is conventional

### Getters & Setters

- Don't wrap fields in trivial getters/setters — Dart fields _are_ the interface
- Use getter for derived/computed values
- Don't define a setter without a corresponding getter
- Avoid returning `this` — use cascade `..` operator instead


## Modern Dart 3.x Features

### Patterns

- Use pattern matching in switch expressions for exhaustive, concise code
- Destructure records: `var (name, age) = getNameAndAge();`
- Use object patterns: `case Rect(width: var w, height: var h):`
- Use guard clauses: `case int n when n > 0:`

### Records

- Use for multiple return values: `(String, int) parse(String s) => ...`
- Access positional fields: `record.$1`, `record.$2`
- Access named fields: `record.name`
- Records are immutable and value-equal by structure

### Sealed Classes & Exhaustiveness

- Use `sealed` for closed type hierarchies (compiler checks exhaustiveness)
- Pattern match on sealed types in switch — no default needed
- Direct subtypes must be in same library

### Enhanced Enums

- Add fields, methods, and implement interfaces on enums
- Use for fixed sets of known values with behavior


## Linter Configuration

Recommended `analysis_options.yaml`:
```yaml
include: package:lints/recommended.yaml

analyzer:
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true
  errors:
    missing_return: error
    dead_code: warning
```

Key recommended linter rules (beyond `package:lints`):
- `prefer_final_locals` — encourages immutability
- `avoid_print` — use proper logging
- `unawaited_futures` — catch missing awaits
- `use_super_parameters` — Dart 2.17+ constructor shorthand
- `unnecessary_lambdas` — use tear-offs
- `prefer_single_quotes` — consistency
- `prefer_const_constructors` — Flutter only; compile-time const optimization
