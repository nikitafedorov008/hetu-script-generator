# AGENTS.md

Guidance for AI coding agents working in this repository.

## Project

`hetu_script_generator` is a build_runner code generator that emits [Hetu Script](https://hetu.dev) ↔ Dart bindings. It is the binding factory for the sibling `../sfw` package (Script Flutter Widget), replacing hand-written `HTExternalClass` boilerplate. Reimplementation of the abandoned hetu-script-autobinding.

Two builders (both registered in `build.yaml` / `lib/builder.dart`):

- **Annotation mode** (`bindings`): `@HetuExternalClass()` on classes/enums you own → `.g.dart` part files (PartBuilder, output formatted by source_gen).
- **Config mode** (`external_bindings`): `@HetuBindings(classes: [...], skip: {...})` on a library/const marker → for classes you CANNOT annotate (Flutter/SDK/3rd-party). Emits two standalone files next to the config: `<name>.hetu.g.dart` (bindings + a `generatedExternalClasses` registration list) and `<name>.ht` (the paired `external class` declarations). Unformatted output by design.

## Commands

- Tests: `dart test` (golden tests via `build_test`'s `testBuilder`)
- Analysis: `dart analyze lib` — keep at 0
- Regenerate the example: `cd example && dart run build_runner build --delete-conflicting-outputs`
- The primary consumer lives in `../sfw` (`lib/bindings/generated/flutter_bindings.dart` config); its runtime test `../sfw/test/generated_bindings_test.dart` executes generated bindings on a live interpreter — run it after emitter changes.

## Architecture

- `lib/src/emitter.dart` — the shared member emitter used by BOTH builders. Produces the `HTExternalClass` + `htFetch`/`htAssign` extension code and returns a `ClassManifest` (constructors/methods with `ParamSig` parameter shapes, getters/setters, enum values) describing exactly what was emitted.
- `lib/src/ht_emitter.dart` — renders manifests into `.ht` declarations. The manifest is the single source of truth, so the two sides cannot drift.
- `lib/src/external_bindings_builder.dart` — the config-mode Builder: resolves the annotation, walks the listed types, writes both outputs (`buildExtensions: {'.dart': ['.hetu.g.dart', '.ht']}` — outputs land next to the config file).
- `lib/src/generator.dart` — the thin annotation-mode `GeneratorForAnnotation` delegating to the emitter.
- `lib/src/runtime_helpers.dart` — the generated-file header (its `ignore_for_file` list must cover every lint the emitted style can trigger).

Emitter behaviors that exist for a reason:

- Closures are typed `({dynamic object, List<dynamic> positionalArgs = const [], Map<String, dynamic> namedArgs = const {}})` — the named `object` is REQUIRED for instance methods (hetu invokes them with the `HTExternalMethod` convention, passing the receiver as `object`); constructors/statics go through `HTExternalFunction`, which this signature also satisfies. Closures missing `object` fall into `Function.apply` with the receiver as a leading positional argument and break on instance-method calls.
- Function-typed parameters get adapters: an incoming `HTFunction` is wrapped into a Dart closure of the right shape (0–2 positional params; non-void returns are cast). Anything else passes through untouched.
- `double` parameters are coerced via `num.toDouble()` (hetu numbers arrive as `int`), respecting nullability; non-nullable `List<T>` parameters are rebuilt with `List<T>.from(x ?? const [])`.
- Defaults are chosen with `== null` checks, NOT `containsKey` — see the hetu gotchas below.
- Synthetic fields are skipped everywhere; getter/setter properties flow through the accessor logic (the analyzer materializes synthetic `FieldElement`s for accessors, and treating them as fields emits assignments for getter-only properties).
- Operators, private and abstract members are skipped; `defaultInstanceIgnore` drops Flutter diagnostics noise (`toString*`, `debugFillProperties`, `createElement`, ...).

## hetu 0.6 gotchas (validated on a live interpreter)

- **`.ht` declarations need real parameter lists.** hetu validates and normalizes call arguments against the declaration: `construct all()` with empty parens silently DROPS the script's arguments, and every omitted named parameter is delivered as an explicit `null` in `namedArgs` (which is why `containsKey`-based defaults are wrong).
- **Bare `construct` swallows a following `construct` keyword** in the parser; emit explicit parameter lists for every constructor when a class has several.
- Named constructors parse as `construct name(...)`; a bare `construct name` also parses standalone but not after a bare unnamed `construct`.

## Testing conventions

- Golden assertions go through `test/matchers.dart` (`containsNormalized` / `notContainsNormalized`) — whitespace-insensitive, so dart_style reformatting of PartBuilder output can't break them. Raw `contains` with embedded newlines WILL break on formatter updates.
- `build_test` hands matchers the output as bytes: wrap matchers in `decodedMatches(...)`.
- Golden tests prove emission shape only; runtime correctness is proven in `../sfw/test/generated_bindings_test.dart` (loads the real generated `.ht` from disk and drives widgets, callbacks, and coercions through a live Hetu).
