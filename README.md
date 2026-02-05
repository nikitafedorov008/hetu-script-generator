# Hetu Script Generator

Reimplementation of [hetu-script-autobinding](https://github.com/hetu-script/hetu-script-autobinding)

### **Note:** The package is in early stage of development, please think carefully before using it in production.

This package provides a build_runner generator that emits Hetu <-> Dart bindings
for annotated classes and functions. It is a single-package (annotations + generator).

Quickstart

- Add to your `pubspec.yaml`:

```yaml
dependencies:
  hetu_script_generator: ^0.1.0

dev_dependencies:
  build_runner: ^2.4.0
  hetu_script_generator: ^0.1.0
```

- Annotate a class and add `part 'x.g.dart';`:

```dart
import 'package:hetu_script_generator/annotations.dart';
import 'package:hetu_script/hetu_script.dart';

part 'person.g.dart';

@HetuExternalClass()
class Person { ... }
```

- Generate:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Status: Binding generator for simple classes and enums. See tests for examples in `example/lib/`.