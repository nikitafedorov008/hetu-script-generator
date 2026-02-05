import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import '../annotations.dart';

class HetuBindingsGenerator extends GeneratorForAnnotation<HetuExternalClass> {
  @override
  FutureOr<String> generateForAnnotatedElement(
      Element element, ConstantReader annotation, BuildStep buildStep) {
    // Support both classes and enums annotated for external binding.
    if (element is! ClassElement && element is! EnumElement) {
      throw InvalidGenerationSourceError(
          'The @HetuExternalClass annotation can only be used on classes or enums.',
          element: element);
    }

    final buffer = StringBuffer();

    // Compute the source filename once — the canonical `part of` will be
    // prepended to the final output (do not write it here to avoid duplicates).
    final sourceFile = buildStep.inputId.pathSegments.last;

    // Enum handling
    if (element is EnumElement) {
      final enumEl = element as EnumElement;
      final enumName = enumEl.name;
      buffer.writeln('// *** hetu_script_generator output for $enumName');

      // Emit namespace/class binding that exposes enum values and `values`
      buffer.writeln('class ${enumName}ClassBinding extends HTExternalClass {');
      buffer.writeln("  ${enumName}ClassBinding() : super('$enumName');");

      buffer.writeln('');
      buffer.writeln('  @override');
      buffer.writeln(
          '  dynamic memberGet(String id, {String? from, bool isRecursive = false, bool ignoreUndefined = false}) {');
      buffer.writeln('    switch (id) {');

      // expose each enum constant as ClassName.Constant
      for (final f in enumEl.fields.where((f) => f.isEnumConstant)) {
        buffer.writeln("      case '$enumName.${f.name}':");
        buffer.writeln('        return $enumName.${f.name};');
      }

      // expose values list
      buffer.writeln("      case '$enumName.values':");
      buffer.writeln('        return $enumName.values;');

      buffer.writeln('      default:');
      buffer.writeln('        throw HTError.undefined(id);');
      buffer.writeln('    }');
      buffer.writeln('  }');

      buffer.writeln('');
      buffer.writeln('  @override');
      buffer.writeln(
          '  void memberSet(String id, dynamic value, {String? from, bool defineIfAbsent = false}) {');
      buffer.writeln('    switch (id) {');
      // enum values are immutable; values list is immutable as well
      for (final f in enumEl.fields.where((f) => f.isEnumConstant)) {
        buffer.writeln("      case '$enumName.${f.name}':");
        buffer.writeln('        throw HTError.immutable(id);');
      }
      buffer.writeln("      case '$enumName.values':");
      buffer.writeln('        throw HTError.immutable(id);');
      buffer.writeln('      default:');
      buffer.writeln('        throw HTError.undefined(id);');
      buffer.writeln('    }');
      buffer.writeln('  }');

      // instance fetch/assign for enum instances (expose index/name)
      buffer.writeln('');
      buffer.writeln('  @override');
      buffer.writeln(
          '  dynamic instanceMemberGet(dynamic instance, String id, {bool ignoreUndefined = false}) {');
      buffer.writeln('    try {');
      buffer.writeln('      return (instance as $enumName).htFetch(id);');
      buffer.writeln('    } on HTError catch (e) {');
      buffer.writeln('      if (!ignoreUndefined) rethrow;');
      buffer.writeln('      return null;');
      buffer.writeln('    }');
      buffer.writeln('  }');

      buffer.writeln('');
      buffer.writeln('  @override');
      buffer.writeln(
          '  void instanceMemberSet(dynamic instance, String id, dynamic value, {bool ignoreUndefined = false}) {');
      buffer.writeln('    try {');
      buffer.writeln('      var i = instance as $enumName;');
      buffer.writeln('      i.htAssign(id, value);');
      buffer.writeln('    } on HTError catch (e) {');
      buffer.writeln('      if (!ignoreUndefined) rethrow;');
      buffer.writeln('    }');
      buffer.writeln('  }');
      buffer.writeln('}');

      // extension for enum instances
      buffer.writeln('');
      buffer.writeln('extension ${enumName}ObjectBinding on $enumName {');
      buffer.writeln('  dynamic htFetch(String varName) {');
      buffer.writeln('    switch (varName) {');
      buffer.writeln("      case 'runtimeType':");
      buffer.writeln("        return const HTExternalType('$enumName');");
      buffer.writeln("      case 'index':");
      buffer.writeln('        return index;');
      buffer.writeln("      case 'name':");
      buffer.writeln('        return name;');
      buffer.writeln('      default:');
      buffer.writeln('        throw HTError.undefined(varName);');
      buffer.writeln('    }');
      buffer.writeln('  }');

      buffer.writeln('');
      buffer.writeln('  void htAssign(String id, dynamic value) {');
      buffer.writeln('    switch (id) {');
      buffer.writeln('      default:');
      buffer.writeln('        throw HTError.undefined(id);');
      buffer.writeln('    }');
      buffer.writeln('  }');
      buffer.writeln('}');

      // remove any accidental `part of` occurrences and return
      var out = buffer.toString();
      out = out.replaceAll(
          RegExp(r"^\s*part of .*?;\s*\r?\n", multiLine: true), '');
      return out;
    }

    // otherwise treat as a regular class
    final clazz = element as ClassElement;
    final className = clazz.name;

    buffer.writeln('// *** hetu_script_generator output for $className');

    // Generate HTExternalClass binding
    buffer.writeln('class ${className}ClassBinding extends HTExternalClass {');
    buffer.writeln("  ${className}ClassBinding() : super('$className');");

    // memberGet
    buffer.writeln('');
    buffer.writeln('  @override');
    buffer.writeln(
        '  dynamic memberGet(String id, {String? from, bool isRecursive = false, bool ignoreUndefined = false}) {');
    buffer.writeln('    switch (id) {');

    // constructors: support unnamed and named constructors (public only)
    for (final c in clazz.constructors) {
      if (c.isPrivate) continue;
      final key = c.name.isEmpty ? className : '$className.${c.name}';
      final ctorCall = _generateConstructorInvocation(className, c);
      buffer.writeln("      case '$key':");
      buffer.writeln(
          '        return ({positionalArgs, namedArgs}) => $ctorCall;');
    }

    // static members (expose as ClassName.member on the Hetu side)
    for (final method in clazz.methods) {
      if (!method.isStatic) continue;
      if (method.isPrivate) continue;
      buffer.writeln("      case '$className.${method.name}':");
      buffer.writeln(
          '        return ({positionalArgs, namedArgs}) => $className.${method.name}(' +
              _generateStaticCallArgs(method) +
              ');');
    }

    // static fields (including simple properties exposed as fields)
    for (final field in clazz.fields) {
      if (!field.isStatic) continue;
      if (field.isPrivate) continue;
      buffer.writeln("      case '$className.${field.name}':");
      buffer.writeln('        return $className.${field.name};');
    }

    // static accessors (setters/getters not represented as fields)
    for (final acc in clazz.accessors) {
      if (!acc.isStatic) continue;
      if (acc.isPrivate) continue;
      // avoid duplicating field-backed accessors
      final propName = acc.displayName.replaceAll('=', '');
      if (clazz.fields.any((f) => f.name == propName)) continue;
      if (acc.isGetter) {
        buffer.writeln("      case '$className.$propName':");
        buffer.writeln('        return $className.$propName;');
      } else if (acc.isSetter) {
        buffer.writeln("      case '$className.$propName':");
        buffer.writeln(
            '        return ({positionalArgs, namedArgs}) => $className.$propName = (positionalArgs.length > 0 ? positionalArgs[0] : null);');
      }
    }

    buffer.writeln('      default:');
    buffer.writeln('        throw HTError.undefined(id);');
    buffer.writeln('    }');
    buffer.writeln('  }');

    // allow setting static and instance members
    buffer.writeln('');
    buffer.writeln('  @override');
    buffer.writeln(
        '  void memberSet(String id, dynamic value, {String? from, bool defineIfAbsent = false}) {');
    buffer.writeln('    switch (id) {');

    // static fields: immutable check or assignment
    for (final field in clazz.fields) {
      if (!field.isStatic) continue;
      if (field.isPrivate) continue;
      buffer.writeln("      case '$className.${field.name}':");
      if (field.isFinal || field.isConst) {
        buffer.writeln('        throw HTError.immutable(id);');
      } else {
        buffer.writeln('        return $className.${field.name} = value;');
      }
    }

    // static setters (accessors)
    for (final acc in clazz.accessors) {
      if (!acc.isStatic) continue;
      if (acc.isPrivate) continue;
      final propName = acc.displayName.replaceAll('=', '');
      // if field exists, already handled
      if (clazz.fields.any((f) => f.name == propName)) continue;
      if (acc.isSetter) {
        buffer.writeln("      case '$className.$propName':");
        buffer.writeln('        return $className.$propName = value;');
      }
    }

    buffer.writeln('      default:');
    buffer.writeln('        throw HTError.undefined(id);');
    buffer.writeln('    }');
    buffer.writeln('  }');

    // instanceMemberGet
    buffer.writeln('');
    buffer.writeln('  @override');
    buffer.writeln(
        '  dynamic instanceMemberGet(dynamic instance, String id, {bool ignoreUndefined = false}) {');
    buffer.writeln('    try {');
    buffer.writeln('      return (instance as $className).htFetch(id);');
    buffer.writeln('    } on HTError catch (e) {');
    buffer.writeln('      if (!ignoreUndefined) rethrow;');
    buffer.writeln('      return null;');
    buffer.writeln('    }');
    buffer.writeln('  }');

    buffer.writeln('');
    buffer.writeln('  @override');
    buffer.writeln(
        '  void instanceMemberSet(dynamic instance, String id, dynamic value, {bool ignoreUndefined = false}) {');
    buffer.writeln('    try {');
    buffer.writeln('      var i = instance as $className;');
    buffer.writeln('      i.htAssign(id, value);');
    buffer.writeln('    } on HTError catch (e) {');
    buffer.writeln('      if (!ignoreUndefined) rethrow;');
    buffer.writeln('    }');
    buffer.writeln('  }');
    buffer.writeln('}');

    // extension with htFetch
    buffer.writeln('');
    buffer.writeln('extension ${className}ObjectBinding on $className {');
    buffer.writeln('  dynamic htFetch(String varName) {');
    buffer.writeln('    switch (varName) {');

    // runtimeType alias
    buffer.writeln("      case 'runtimeType':");
    buffer.writeln("        return const HTExternalType('$className');");

    // If this is a StatefulWidget expose common widget members
    final isStateful = _extendsFrom(clazz, 'StatefulWidget');
    if (isStateful) {
      // prefer exposing 'child' and 'createState' when present
      if (clazz.fields.any((f) => !f.isStatic && f.name == 'child')) {
        buffer.writeln("      case 'child':");
        buffer.writeln('        return child;');
      }
      buffer.writeln("      case 'createState':");
      buffer.writeln(
          '        return ({positionalArgs, namedArgs}) => createState();');
    }

    // collect instance fields (declared + inherited) — emitted below with
    // proper deduplication to avoid duplicate `case` entries.
    final instanceFields = _collectInstanceFields(clazz);

    // methods (public, instance)
    for (final method in clazz.methods) {
      if (method.isStatic) continue;
      if (method.isPrivate) continue;
      if (method.isAbstract) continue;

      buffer.writeln("      case '${method.name}':");
      buffer.writeln('        return ({positionalArgs, namedArgs}) => ' +
          _generateInstanceMethodCall(method) +
          ';');
    }

    // instance members (fields + accessors). avoid duplicates by tracking
    final emittedInstance = <String>{};

    // instance fields: emit declared fields first (preserve order), then
    // inherited fields (if any) so behavior is predictable.
    final declaredInstanceFields =
        clazz.fields.where((f) => !f.isStatic && !f.isPrivate).toList();
    final inheritedInstanceFields = instanceFields
        .where((f) => !declaredInstanceFields.contains(f))
        .toList();

    for (final field in [
      ...declaredInstanceFields,
      ...inheritedInstanceFields
    ]) {
      emittedInstance.add(field.name);
      buffer.writeln("      case '${field.name}':");
      buffer.writeln('        return ${field.name};');
    }

    // instance accessors — emit getter *only* when a getter exists and
    // do not emit a fetch for setter-only properties. Track emitted names to
    // avoid duplicates with declared fields.
    // build a quick map of property -> (hasGetter, hasSetter) so we can emit
    // the correct branches independently.
    // collect accessors (getter/setter presence) from class + supertypes
    final _instanceAccessors = _collectInstanceAccessors(clazz);

    for (final entry in _instanceAccessors.entries) {
      final propName = entry.key;
      // Verify the getter truly exists (including on supertypes) using analyzer
      final getterExists = entry.value['get']! && hasGetter(clazz, propName);
      // if a declared field already emitted this name, skip
      if (emittedInstance.contains(propName)) continue;
      if (getterExists) {
        emittedInstance.add(propName);
        buffer.writeln("      case '$propName':");
        buffer.writeln('        return $propName;');
      }
      // Note: do NOT emit a fetch if only a setter exists — that will be
      // covered by the htAssign generation (below) which emits setter cases
      // only when a setter is present.
    }

    buffer.writeln('      default:');
    buffer.writeln('        throw HTError.undefined(varName);');
    buffer.writeln('    }');
    buffer.writeln('  }');

    // instance assignment (fields + static-backed properties exposed on instances)
    buffer.writeln('');
    buffer.writeln('  void htAssign(String id, dynamic value) {');
    buffer.writeln('    switch (id) {');

    // track which names we've emitted for assignment to avoid duplicates
    final emittedAssigns = <String>{};

    // instance fields
    for (final field in clazz.fields) {
      if (field.isStatic) continue;
      if (field.isPrivate) continue;
      emittedAssigns.add(field.name);
      buffer.writeln("      case '${field.name}':");
      if (field.isFinal || field.isConst) {
        buffer.writeln('        throw HTError.immutable(id);');
      } else {
        buffer.writeln('        ${field.name} = value;');
        buffer.writeln('        break;');
      }
    }

    // instance accessors (generate setter cases only when a setter exists).
    // This allows setter-only properties (including inherited ones) to be
    // writable from Hetu while not exposing a getter when none exists.
    for (final entry in _instanceAccessors.entries) {
      final propName = entry.key;
      // skip names already emitted for declared fields
      if (emittedAssigns.contains(propName)) continue;

      // decide whether a setter should be emitted:
      //  - allow if there is a non-final backing field (synthetic setter),
      //  - or if an explicit setter accessor is declared on the class/tree.
      final hasNonFinalBacking = instanceFields
          .any((f) => f.name == propName && !(f.isFinal || f.isConst));
      final setterElement = clazz.lookUpSetter(propName, clazz.library);
      final hasExplicitSetter =
          setterElement != null && !setterElement.isSynthetic;
      final shouldEmitSetter = hasNonFinalBacking || hasExplicitSetter;
      if (!shouldEmitSetter) continue;

      // locate a backing field (declared or inherited) if present
      FieldElement? backing;
      for (final f in instanceFields) {
        if (f.name == propName) {
          backing = f;
          break;
        }
      }
      if (backing != null) {
        if (backing.isFinal || backing.isConst) {
          buffer.writeln("      case '$propName':");
          buffer.writeln('        throw HTError.immutable(id);');
          continue;
        }
        emittedAssigns.add(propName);
        buffer.writeln("      case '$propName':");
        buffer.writeln('        $propName = value;');
        buffer.writeln('        break;');
        continue;
      }

      // no backing field visible — rely on explicit setter implementation
      emittedAssigns.add(propName);
      buffer.writeln("      case '$propName':");
      buffer.writeln('        $propName = value;');
      buffer.writeln('        break;');
    }

    // static-backed properties that should be reachable via instance (e.g. level)
    for (final acc in clazz.accessors) {
      if (!acc.isStatic) continue;
      if (acc.isPrivate) continue;
      final propName = acc.displayName.replaceAll('=', '');
      // skip if already emitted
      if (emittedAssigns.contains(propName)) continue;
      // only include static properties that have a setter or are explicitly desired
      if (acc.isSetter) {
        buffer.writeln("      case '$propName':");
        // check if corresponding field is final/const
        final hasBacking = clazz.fields.any((f) => f.name == propName);
        if (hasBacking) {
          final backingField =
              clazz.fields.firstWhere((f) => f.name == propName);
          if (backingField.isFinal || backingField.isConst) {
            buffer.writeln('        throw HTError.immutable(id);');
          } else {
            buffer.writeln('        ${className}.${propName} = value;');
            buffer.writeln('        break;');
          }
        } else {
          // no backing field visible — assume setter is available
          buffer.writeln('        ${className}.${propName} = value;');
          buffer.writeln('        break;');
        }
      }
    }

    buffer.writeln('      default:');
    buffer.writeln('        throw HTError.undefined(id);');
    buffer.writeln('    }');
    buffer.writeln('  }');
    buffer.writeln('}');

    // Emit a standalone `.g.dart` (restore previous behavior): remove any
    // accidental `part of` lines and prepend a single canonical directive.
    var out = buffer.toString();
    out = out.replaceAll(
        RegExp(r"^\s*part of .*?;\s*\r?\n", multiLine: true), '');
    //out = "part of '$sourceFile';\n\n" + out;
    return out;
  }

  // Collect all accessible instance fields from the class and its
  // supertypes / mixins / interfaces (exclude private/static/Object).
  List<FieldElement> _collectInstanceFields(ClassElement c) {
    final seen = <String>{};
    final out = <FieldElement>[];
    dynamic current = c.thisType;
    while (current != null && current.element.name != 'Object') {
      final curClass = current.element;
      for (final f in curClass.fields) {
        if (f.isStatic) continue;
        if (f.isPrivate) continue;
        if (seen.add(f.name)) out.add(f);
      }
      // mixins
      for (final mix in curClass.mixins) {
        final mixClass = mix.element;
        for (final f in mixClass.fields) {
          if (f.isStatic) continue;
          if (f.isPrivate) continue;
          if (seen.add(f.name)) out.add(f);
        }
      }
      // interfaces (may declare abstract fields/accessors)
      for (final intf in curClass.interfaces) {
        final intfClass = intf.element;
        for (final f in intfClass.fields) {
          if (f.isStatic) continue;
          if (f.isPrivate) continue;
          if (seen.add(f.name)) out.add(f);
        }
      }
      final next = curClass.supertype;
      if (next == null) break;
      current = next;
    }
    return out;
  }

  // Collect instance accessors (getter/setter presence) from class and
  // inherited types. Result maps property name -> {'get': bool, 'set': bool}.
  Map<String, Map<String, bool>> _collectInstanceAccessors(ClassElement c) {
    final result = <String, Map<String, bool>>{};
    void register(var acc) {
      if (acc.isStatic) return;
      if (acc.isPrivate) return;
      final name = acc.displayName.replaceAll('=', '');
      final map = result.putIfAbsent(name, () => {'get': false, 'set': false});
      if (acc.isGetter) map['get'] = true;
      if (acc.isSetter) map['set'] = true;
    }

    dynamic current = c.thisType;
    while (current != null && current.element.name != 'Object') {
      final curClass = current.element;
      for (final acc in curClass.accessors) register(acc);
      for (final mix in curClass.mixins) {
        for (final acc in mix.element.accessors) register(acc);
      }
      for (final intf in curClass.interfaces) {
        for (final acc in intf.element.accessors) register(acc);
      }
      final next = curClass.supertype;
      if (next == null) break;
      current = next;
    }

    return result;
  }

  // Helper: accessor/type utilities used by the emitter. These centralize
  // the analyzer lookups and make intent explicit in the generation code.
  bool hasGetter(ClassElement c, String name) =>
      c.lookUpGetter(name, c.library) != null;

  bool hasSetter(ClassElement c, String name) =>
      c.lookUpSetter(name, c.library) != null;

  bool declaresExplicitGetter(ClassElement c, String name) => c.accessors
      .any((a) => a.isGetter && !a.isSynthetic && a.displayName == name);

  bool declaresExplicitSetter(ClassElement c, String name) => c.accessors
      .any((a) => a.isSetter && !a.isSynthetic && a.displayName == '$name=');

  bool fieldIsMutable(FieldElement f) =>
      !f.isFinal && !f.isConst && !f.isStatic;

  String _generateConstructorInvocation(
      String className, ConstructorElement ctor) {
    final ctorPrefix =
        ctor.name.isEmpty ? className : '$className.${ctor.name}';
    if (ctor.parameters.isEmpty) return '${ctorPrefix}()';

    final positional = <String>[];
    final named = <String>[];

    for (var i = 0; i < ctor.parameters.length; i++) {
      final p = ctor.parameters[i];
      if (p.isPositional) {
        if (p.hasDefaultValue && p.defaultValueCode != null) {
          positional.add(
              "positionalArgs.length > $i ? positionalArgs[$i] : ${p.defaultValueCode}");
        } else {
          positional
              .add("positionalArgs.length > $i ? positionalArgs[$i] : null");
        }
      } else if (p.isNamed) {
        if (p.hasDefaultValue && p.defaultValueCode != null) {
          named.add(
              "${p.name}: namedArgs.containsKey('${p.name}') ? namedArgs['${p.name}'] : ${p.defaultValueCode}");
        } else {
          named.add(
              "${p.name}: namedArgs.containsKey('${p.name}') ? namedArgs['${p.name}'] : null");
        }
      }
    }

    final posText = positional.join(', ');
    final namedText = named.isNotEmpty
        ? (positional.isNotEmpty ? ', ' : '') + named.join(', ')
        : '';
    return '${ctorPrefix}($posText$namedText)';
  }

  String _generateInstanceMethodCall(MethodElement method) {
    final paramInvocations = <String>[];
    for (var i = 0; i < method.parameters.length; i++) {
      final p = method.parameters[i];
      if (p.isPositional) {
        paramInvocations
            .add('positionalArgs.length > $i ? positionalArgs[$i] : null');
      } else if (p.isNamed) {
        paramInvocations.add(
            "${p.name}: namedArgs.containsKey('${p.name}') ? namedArgs['${p.name}'] : null");
      }
    }

    final invocation =
        '(${method.parameters.isEmpty ? '' : paramInvocations.join(', ')})';
    // Inside the generated extension method we can call the instance method
    // directly (this is the extension receiver). Avoid referencing an
    // `object` identifier which does not exist in that closure scope.
    return '${method.name}$invocation';
  }

  String _generateStaticCallArgs(MethodElement method) {
    final args = <String>[];
    for (var i = 0; i < method.parameters.length; i++) {
      final p = method.parameters[i];
      if (p.isPositional) {
        args.add('positionalArgs.length > $i ? positionalArgs[$i] : null');
      } else if (p.isNamed) {
        args.add(
            "${p.name}: namedArgs.containsKey('${p.name}') ? namedArgs['${p.name}'] : null");
      }
    }
    return args.join(', ');
  }

  bool _extendsFrom(ClassElement c, String baseName) {
    var sup = c.supertype;
    while (sup != null) {
      if (sup.element.name == baseName) return true;
      sup = sup.element.supertype;
    }
    return false;
  }
}
