import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:test/test.dart';
import 'package:hetu_script_generator/builder.dart' as builder_pkg;

import 'matchers.dart';

void main() {
  final builder = builder_pkg.externalBindingsBuilder(BuilderOptions({}));

  const widgetsSrc = '''
class FakeWidget {
  const FakeWidget();
}

enum FakeAlign { left, right }

class FakeButton extends FakeWidget {
  final void Function()? onTap;
  final void Function(int)? onCount;
  final double? width;
  final List<FakeWidget>? children;
  final String? label;

  const FakeButton(
      {this.onTap, this.onCount, this.width, this.children, this.label});

  const FakeButton.compact(this.label)
      : onTap = null,
        onCount = null,
        width = null,
        children = null;

  String debugInfo() => 'x';

  static FakeButton make() => const FakeButton();
}
''';

  const configSrc = '''
import 'package:hetu_script_generator/annotations.dart';

import 'widgets.dart';

@HetuBindings(classes: [FakeButton, FakeAlign], skip: {FakeButton: ['debugInfo']})
const fakeBindings = true;
''';

  test('config mode emits standalone bindings and paired .ht declarations',
      () async {
    await testBuilder(
      builder,
      {
        'a|lib/widgets.dart': widgetsSrc,
        'a|lib/bindings.dart': configSrc,
      },
      outputs: {
        'a|lib/bindings.hetu.g.dart': decodedMatches(allOf(
          containsNormalized([
            // imports carried over from the config file + hetu
            "import 'package:hetu_script/hetu_script.dart';",
            "import 'package:hetu_script/values.dart';",
            // class binding with the hetu 0.6 closure convention
            'class FakeButtonClassBinding extends HTExternalClass',
            'List<dynamic> positionalArgs = const []',
            // callback adapters: 0-arg and 1-arg with typed parameter
            "(namedArgs['onTap']) is HTFunction",
            '.call(positionalArgs: [a0])',
            'int a0',
            // double coercion and typed list rebuild
            'as num?)?.toDouble()',
            'List<FakeWidget>.from',
            // named constructor + static method
            "case 'FakeButton.compact':",
            "case 'FakeButton.make':",
            // enum binding
            "case 'FakeAlign.left':",
            "case 'FakeAlign.values':",
            // aggregate registration list
            'final List<HTExternalClass> generatedExternalClasses = [',
            'FakeButtonClassBinding(),',
            'FakeAlignClassBinding(),',
          ]),
          // skip: entry from the annotation
          notContainsNormalized(["case 'debugInfo':"]),
        )),
        'a|lib/bindings.ht': decodedMatches(allOf(
          containsNormalized([
            'external class FakeButton {',
            'construct',
            'construct compact',
            'static fun make()',
            'get label',
            'get width',
            'external class FakeAlign {',
            'static get left',
            'static get right',
            'static get values',
            'get index',
            'get name',
          ]),
          notContainsNormalized(['fun debugInfo']),
        )),
      },
      reader: await PackageAssetReader.currentIsolate(),
    );
  });

  test('files without @HetuBindings produce no outputs', () async {
    await testBuilder(
      builder,
      {
        'a|lib/widgets.dart': widgetsSrc,
      },
      outputs: {},
      reader: await PackageAssetReader.currentIsolate(),
    );
  });
}
