import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:test/test.dart';
import 'package:hetu_script_generator/builder.dart' as builder_pkg;

import 'matchers.dart';

void main() {
  // shared builder for tests
  final builder = builder_pkg.bindingsBuilder(BuilderOptions({}));

  test(
      'generates widget-style binding for StatefulWidget (ScriptContainer-like)',
      () async {
    final src = r"""
import 'package:flutter/widgets.dart';
import 'package:hetu_script_generator/annotations.dart';

part 'script_container.g.dart';

@HetuExternalClass()
class ScriptContainer extends StatefulWidget {
  const ScriptContainer({required this.child, Key? key}): super(key: key);
  final dynamic child;
  static void rebuild(Object? o) {}
  static void reload(Object? o) {}
  @override
  State<ScriptContainer> createState() => throw UnimplementedError();
}
""";

    await testBuilder(
      builder,
      {
        'a|lib/script_container.dart': src,
      },
      outputs: {
        'a|lib/script_container.g.dart': decodedMatches(containsNormalized([
          "case 'ScriptContainer.rebuild':",
          "case 'child':",
          "case 'createState':",
          'List<dynamic> positionalArgs = const []',
          'Map<String, dynamic> namedArgs = const {}',
        ])),
      },
      reader: await PackageAssetReader.currentIsolate(),
    );
  });
}
