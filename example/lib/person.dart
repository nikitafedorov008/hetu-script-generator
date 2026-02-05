import 'package:hetu_script/binding.dart';
import 'package:hetu_script/hetu_script.dart';
import 'package:hetu_script/types.dart';
import 'package:hetu_script_generator/annotations.dart';

part 'person.g.dart';

@HetuExternalClass()
class Person {
  final String name;
  Person(this.name);
  String greet() => 'hi $name';
}
