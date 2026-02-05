import 'package:source_gen/source_gen.dart';
import 'package:build/build.dart';

import 'src/generator.dart';
import 'src/runtime_helpers.dart' as helpers;

/// Emit a standalone `.g.dart` part directly. This matches the previous
/// behaviour used by the project and avoids reliance on a separate
/// combining builder step in some environments/CI.
Builder bindingsBuilder(BuilderOptions options) => PartBuilder(
      [HetuBindingsGenerator()],
      '.g.dart',
      header: helpers.generatedHeader,
    );
