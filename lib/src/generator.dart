import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import '../annotations.dart';
import 'emitter.dart';

/// Annotation mode: generates a binding for a class/enum you own and marked
/// with `@HetuExternalClass()`. The member emission logic is shared with the
/// config-driven [ExternalBindingsBuilder] via `emitter.dart`.
class HetuBindingsGenerator extends GeneratorForAnnotation<HetuExternalClass> {
  @override
  FutureOr<String> generateForAnnotatedElement(
      Element element, ConstantReader annotation, BuildStep buildStep) {
    final buffer = StringBuffer();
    if (element is EnumElement) {
      emitEnumBinding(element, buffer);
    } else if (element is ClassElement) {
      emitClassBinding(element, buffer);
    } else {
      throw InvalidGenerationSourceError(
          'The @HetuExternalClass annotation can only be used on classes or enums.',
          element: element);
    }

    // PartBuilder prepends the canonical `part of`; strip any accidental ones.
    return buffer
        .toString()
        .replaceAll(RegExp(r'^\s*part of .*?;\s*\r?\n', multiLine: true), '');
  }
}
