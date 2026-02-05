import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:test/test.dart';
import 'package:hetu_script_generator/builder.dart' as builder_pkg;

void main() {
  // shared builder for tests
  final builder = builder_pkg.bindingsBuilder(BuilderOptions({}));
  test('generates binding for simple Person class', () async {
    final src = r"""
import 'package:hetu_script_generator/annotations.dart';

part 'person.g.dart';

@HetuExternalClass()
class Person {
  final String name;
  Person(this.name);
  String greet() => 'hi $name';
}
""";

    final expectedPieces = [
      'class PersonClassBinding extends HTExternalClass',
      'extension PersonObjectBinding on Person',
      "case 'greet':",
      "return ({positionalArgs, namedArgs}) =>",
    ];

    // Use the builder declared in this package
    await testBuilder(
      builder,
      {
        'a|lib/person.dart': src,
      },
      outputs: {
        'a|lib/person.g.dart': containsAll(expectedPieces),
      },
      reader: await PackageAssetReader.currentIsolate(),
    );
  });

  test('generates binding for Human.withName (named ctor + default)', () async {
    final src = r"""
import 'package:hetu_script_generator/annotations.dart';

part 'human.g.dart';

@HetuExternalClass()
class Human {
  static final races = <String>['Caucasion'];
  static String _level = '0';
  static String get level => _level;
  static set level(value) => _level = value;
  static String meaning(int n) => 'The meaning of life is $n';

  String get child => 'Tom';
  String name;
  String race;

  Human([this.name = 'Jimmy', this.race = 'Caucasion']);
  Human.withName(this.name, [this.race = 'Caucasion']);

  void greeting(String tag) {
    print('Hi! $tag');
  }
}
""";

    final expected = [
      "case 'Human.withName':",
      "Human.withName(positionalArgs.length > 0 ? positionalArgs[0]",
      "positionalArgs.length > 1 ? positionalArgs[1] : 'Caucasion'",
      // static getter exposed on the class
      "case 'Human.level':",
      "return Human.level;",
      // static setter exposed on the class
      "return Human.level = value;",
      // static final should be immutable
      "case 'Human.races':",
      "throw HTError.immutable(id);",
      // instance-side assignment for static-backed property
      "case 'level':",
      "Human.level = value",
    ];

    await testBuilder(
      builder,
      {
        'a|lib/human.dart': src,
      },
      outputs: {
        'a|lib/human.g.dart': allOf(containsAll(expected),
            isNot(contains("case 'child':\n        child = value"))),
      },
      reader: await PackageAssetReader.currentIsolate(),
    );
  });

  test('generates binding for simple enum (values + instance props)', () async {
    final src = r"""
import 'package:hetu_script_generator/annotations.dart';

part 'ingredients.g.dart';

@HetuExternalClass()
enum Ingredients { Apple, Banana, Cinnamon }
""";

    final expected = [
      'class IngredientsClassBinding extends HTExternalClass',
      "case 'Ingredients.Apple':",
      "case 'Ingredients.values':",
      'extension IngredientsObjectBinding on Ingredients',
      "case 'index':",
      "case 'name':",
    ];

    await testBuilder(
      builder,
      {
        'a|lib/ingredients.dart': src,
      },
      outputs: {
        'a|lib/ingredients.g.dart':
            allOf(containsAll(expected), isNot(contains("index = value"))),
      },
      reader: await PackageAssetReader.currentIsolate(),
    );
  });

  test(
      'does not generate assignment for getter-only props and avoids duplicates',
      () async {
    final src = r"""
import 'package:hetu_script_generator/annotations.dart';

part 'human.g.dart';

@HetuExternalClass()
class Human {
  String get child => 'Tom';
  String name;
  Human(this.name);
}
""";

    await testBuilder(
      builder,
      {
        'a|lib/human.dart': src,
      },
      outputs: {
        'a|lib/human.g.dart': allOf(
          isNot(contains("case 'child':\n        child = value")),
          isNot(contains(
              "case 'name':\n        return name;\n      case 'name':")),
        ),
      },
      reader: await PackageAssetReader.currentIsolate(),
    );
  });

  test('generates assignment for setter-only props but not a fetch', () async {
    final src = r"""
import 'package:hetu_script_generator/annotations.dart';

part 'human.g.dart';

@HetuExternalClass()
class Human {
  set child(String _) {}
  String name;
  Human(this.name);
}
""";

    await testBuilder(
      builder,
      {
        'a|lib/human_setter_only.dart': src,
      },
      outputs: {
        'a|lib/human_setter_only.g.dart': allOf(
          contains("case 'child':\n        child = value"),
          isNot(contains("case 'child':\n        return child;")),
        ),
      },
      reader: await PackageAssetReader.currentIsolate(),
    );
  });

  test('inherits getter-only prop from base class (emit fetch only)', () async {
    final src = r"""
import 'package:hetu_script_generator/annotations.dart';

part 'derived.g.dart';

class Base {
  String get inherited => 'x';
}

@HetuExternalClass()
class Derived extends Base {}
""";

    await testBuilder(
      builder,
      {
        'a|lib/derived.dart': src,
      },
      outputs: {
        'a|lib/derived.g.dart': allOf(
          contains("case 'inherited':\n        return inherited;"),
          isNot(contains("case 'inherited':\n        inherited = value")),
        ),
      },
      reader: await PackageAssetReader.currentIsolate(),
    );
  });

  test('inherits setter-only prop from base class (emit assign only)',
      () async {
    final src = r"""
import 'package:hetu_script_generator/annotations.dart';

part 'derived.g.dart';

class Base {
  set inherited(String _) {}
}

@HetuExternalClass()
class Derived extends Base {}
""";

    await testBuilder(
      builder,
      {
        'a|lib/derived_setter.dart': src,
      },
      outputs: {
        'a|lib/derived_setter.g.dart': allOf(
          contains("case 'inherited':\n        inherited = value"),
          isNot(contains("case 'inherited':\n        return inherited;")),
        ),
      },
      reader: await PackageAssetReader.currentIsolate(),
    );
  });
}
