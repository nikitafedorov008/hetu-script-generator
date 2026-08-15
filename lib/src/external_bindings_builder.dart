// Config-driven builder: reads a @HetuBindings(classes: [...]) marker in the
// consuming package and emits, next to it:
//   <name>.hetu.g.dart — standalone bindings + `generatedExternalClasses`
//   <name>.ht         — the paired Hetu `external class` declarations
// This is how classes you cannot annotate (Flutter/SDK/3rd party) get bound.
import 'dart:async';

import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import '../annotations.dart';
import 'emitter.dart';
import 'ht_emitter.dart';
import 'runtime_helpers.dart' as helpers;

class ExternalBindingsBuilder implements Builder {
  @override
  Map<String, List<String>> get buildExtensions => const {
        '.dart': ['.hetu.g.dart', '.ht'],
      };

  static const TypeChecker _checker = TypeChecker.fromRuntime(HetuBindings);

  @override
  Future<void> build(BuildStep buildStep) async {
    final inputId = buildStep.inputId;
    if (inputId.path.endsWith('.g.dart')) return;

    // Cheap pre-filter before resolving the library.
    final source = await buildStep.readAsString(inputId);
    if (!source.contains('HetuBindings')) return;
    if (!await buildStep.resolver.isLibrary(inputId)) return;

    final library = await buildStep.resolver.libraryFor(inputId);
    final config = _findConfig(library);
    if (config == null) return;

    final classObjs = config.getField('classes')?.toListValue() ?? const [];
    final skipByName = _readSkipMap(config);

    final code = StringBuffer(helpers.generatedHeader);
    for (final uri in _collectImports(library)) {
      code.writeln("import '$uri';");
    }
    code.writeln('');

    final manifests = <ClassManifest>[];
    final bindingCtors = <String>[];
    for (final obj in classObjs) {
      final el = obj.toTypeValue()?.element;
      if (el is EnumElement) {
        manifests.add(emitEnumBinding(el, code));
        bindingCtors.add('${el.name}ClassBinding()');
      } else if (el is ClassElement) {
        final options = EmitOptions(skip: skipByName[el.name] ?? const {});
        manifests.add(emitClassBinding(el, code, options: options));
        bindingCtors.add('${el.name}ClassBinding()');
      } else {
        log.warning(
            'HetuBindings: unsupported entry $obj — only classes and enums are supported.');
      }
      code.writeln('');
    }

    code.writeln('/// Every generated external class, ready to be passed to');
    code.writeln('/// `Hetu.init(externalClasses: ...)` or a BindingHandler.');
    code.writeln('final List<HTExternalClass> generatedExternalClasses = [');
    for (final ctor in bindingCtors) {
      code.writeln('  $ctor,');
    }
    code.writeln('];');

    await buildStep.writeAsString(
        inputId.changeExtension('.hetu.g.dart'), code.toString());
    await buildStep.writeAsString(
        inputId.changeExtension('.ht'), emitHtDeclarations(manifests));
  }

  DartObject? _findConfig(LibraryElement library) {
    for (final meta in library.metadata) {
      final v = meta.computeConstantValue();
      if (v?.type != null && _checker.isExactlyType(v!.type!)) return v;
    }
    for (final unit in library.units) {
      for (final el in <Element>[
        ...unit.topLevelVariables,
        ...unit.classes,
        ...unit.functions,
      ]) {
        final ann = _checker.firstAnnotationOf(el, throwOnUnresolved: false);
        if (ann != null) return ann;
      }
    }
    return null;
  }

  Map<String, Set<String>> _readSkipMap(DartObject config) {
    final skipByName = <String, Set<String>>{};
    final skipObj = config.getField('skip')?.toMapValue() ?? const {};
    skipObj.forEach((k, v) {
      final name = k?.toTypeValue()?.element?.name;
      if (name == null) return;
      skipByName[name] = (v?.toListValue() ?? const [])
          .map((o) => o.toStringValue())
          .whereType<String>()
          .toSet();
    });
    return skipByName;
  }

  Iterable<String> _collectImports(LibraryElement library) {
    final uris = <String>{};
    for (final imp in library.libraryImports) {
      final uri = imp.importedLibrary?.source.uri.toString();
      if (uri == null) continue;
      if (uri == 'dart:core') continue;
      if (uri.startsWith('package:hetu_script_generator/')) continue;
      uris.add(uri);
    }
    uris.addAll(const [
      // dart:ui symbols (ColorSpace etc.) appear in Flutter default values
      // but are not all re-exported by material.dart.
      'dart:ui',
      'package:hetu_script/hetu_script.dart',
      'package:hetu_script/binding.dart',
      'package:hetu_script/values.dart',
      'package:hetu_script/type/external.dart',
    ]);
    return uris;
  }
}
