import 'package:source_gen/source_gen.dart';
import 'package:build/build.dart';

import 'src/external_bindings_builder.dart';
import 'src/generator.dart';
import 'src/runtime_helpers.dart' as helpers;

/// Annotation mode: `@HetuExternalClass()` on your own classes -> `.g.dart`
/// part files.
Builder bindingsBuilder(BuilderOptions options) => PartBuilder(
      [HetuBindingsGenerator()],
      '.g.dart',
      header: helpers.generatedHeader,
    );

/// Config mode: `@HetuBindings(classes: [...])` marker -> standalone
/// `.hetu.g.dart` bindings + paired `.ht` declarations.
Builder externalBindingsBuilder(BuilderOptions options) =>
    ExternalBindingsBuilder();
