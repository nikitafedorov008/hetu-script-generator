import 'package:hetu_script/hetu_script.dart';
import 'package:hetu_script/binding.dart';
import 'package:hetu_script/types.dart';
import 'package:hetu_script_generator/annotations.dart';

part 'example.g.dart';

@HetuExternalClass()
class Person {
  final String name;
  Person(this.name);

  String greet() => 'hi $name';
}

@HetuExternalClass()
class Human {
  static final races = <String>['Caucasian'];
  static String _level = '0';
  static String get level => _level;
  static set level(value) => _level = value;
  static String meaning(int n) => 'The meaning of life is $n';

  String get child => 'Tom';
  String name;
  String race;

  Human([this.name = 'Jimmy', this.race = 'Caucasian']);
  Human.withName(this.name, [this.race = 'Caucasian']);

  void greeting(String tag) {
    print('Hi! $tag');
  }
}

void main(List<String> arguments) {
  print('${Person('John').greet()}!');
}
