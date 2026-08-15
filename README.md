# Hetu Script Generator

Reimplementation of [hetu-script-autobinding](https://github.com/hetu-script/hetu-script-autobinding): a build_runner generator that emits Hetu ↔ Dart bindings, targeting hetu_script 0.6. Powers the bindings of [sfw](https://github.com/nikitafedorov008/sfw) (Script Flutter Widget).

### **Note:** early stage of development, think carefully before using it in production.

## Two modes

### 1. Annotation mode — for classes you own

```dart
import 'package:hetu_script_generator/annotations.dart';
import 'package:hetu_script/hetu_script.dart';

part 'person.g.dart';

@HetuExternalClass()
class Person { ... }
```

```bash
dart run build_runner build --delete-conflicting-outputs
```

Emits a `PersonClassBinding extends HTExternalClass` + `htFetch`/`htAssign` extension as a part file.

### 2. Config mode — for Flutter/SDK/3rd-party classes you cannot annotate

```dart
// lib/bindings/flutter_bindings.dart
import 'package:flutter/material.dart';
import 'package:hetu_script_generator/annotations.dart';

@HetuBindings(
  classes: [Text, Column, Container, EdgeInsets, Colors, MainAxisAlignment],
  skip: {Container: ['someMember']},
)
const flutterBindings = true;
```

The `external_bindings` builder emits TWO files next to the config:

- `flutter_bindings.hetu.g.dart` — standalone bindings plus a ready-to-register list:
  `final List<HTExternalClass> generatedExternalClasses = [...]`
- `flutter_bindings.ht` — the paired Hetu `external class` declarations **with real
  parameter signatures** (hetu validates call arguments against the declaration),
  ready to ship as a Flutter asset and `import` from scripts.

Generated bindings automatically:

- adapt function-typed parameters (`HTFunction` → typed Dart closure, e.g. `VoidCallback`, `ValueChanged<bool>`);
- coerce `int` → `double` parameters (hetu numbers arrive as `int`);
- rebuild `List<T>` parameters from script lists (`List<Widget>.from(...)`);
- pick Dart-side default values correctly under hetu's argument normalization;
- skip operators, private members and Flutter diagnostics noise (plus per-class `skip:`).

## Setup

```yaml
dev_dependencies:
  build_runner: ^2.4.0
  hetu_script_generator:
    git: https://github.com/nikitafedorov008/hetu_script_generator
```

Scope the builder in your `build.yaml` to the config file:

```yaml
targets:
  $default:
    builders:
      hetu_script_generator|external_bindings:
        generate_for:
          - lib/bindings/flutter_bindings.dart
```

Status: constructors (incl. named), static/instance members, enums, callback adapters, type coercions. See `test/` for golden examples and `../sfw` for a real consumer with a live-interpreter test suite.
