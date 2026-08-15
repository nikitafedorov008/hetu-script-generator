// Shared binding emitter used by both builders (annotation mode and
// @HetuBindings config mode). Emits HTExternalClass subclasses + htFetch
// extensions, and records what was emitted in a [ClassManifest] so the
// `.ht` emitter can mirror the exact surface.
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

/// Instance members that are framework/diagnostics noise inside scripts.
const Set<String> defaultInstanceIgnore = {
  'toString',
  'toStringShort',
  'toStringShallow',
  'toStringDeep',
  'toDiagnosticsNode',
  'debugFillProperties',
  'debugDescribeChildren',
  'createElement',
  'createRenderObject',
  'updateRenderObject',
  'didUnmountRenderObject',
  'debugTypicalAncestorWidgetClass',
  'noSuchMethod',
  'hashCode',
};

class EmitOptions {
  /// Extra member names to skip for this class (merged with the default
  /// ignore list).
  final Set<String> skip;

  const EmitOptions({this.skip = const {}});

  bool skipped(String name) =>
      skip.contains(name) || defaultInstanceIgnore.contains(name);
}

/// Parameter shape of a callable, used to render the exact hetu-side
/// signature (hetu validates call arguments against the declaration, so the
/// `.ht` file must carry real parameter lists).
class ParamSig {
  final List<String> positional;
  final List<String> optionalPositional;
  final List<String> named;

  ParamSig(this.positional, this.optionalPositional, this.named);

  static ParamSig of(List<ParameterElement> params) => ParamSig(
        params.where((p) => p.isRequiredPositional).map((p) => p.name).toList(),
        params.where((p) => p.isOptionalPositional).map((p) => p.name).toList(),
        params.where((p) => p.isNamed).map((p) => p.name).toList(),
      );

  /// Renders `(a, b, [c], {d, e})` in hetu syntax.
  String toHt() {
    final parts = <String>[...positional];
    if (optionalPositional.isNotEmpty) {
      parts.add('[${optionalPositional.join(', ')}]');
    }
    if (named.isNotEmpty) {
      parts.add('{${named.join(', ')}}');
    }
    return '(${parts.join(', ')})';
  }
}

/// What was actually emitted for one class — the source of truth for the
/// paired `.ht` declaration.
class ClassManifest {
  final String name;
  final bool isEnum;
  final List<String> enumValues = [];

  /// name ('' for the unnamed constructor) + parameter shape.
  final List<(String, ParamSig)> constructors = [];
  final List<(String, ParamSig)> staticMethods = [];
  final List<String> staticGetters = [];
  final List<String> staticSetters = [];
  final List<(String, ParamSig)> instanceMethods = [];
  final List<String> instanceGetters = [];
  final List<String> instanceSetters = [];

  ClassManifest(this.name, {this.isEnum = false});
}

// The universal closure signature: hetu invokes external functions with
// named positionalArgs/namedArgs (HTExternalFunction), and INSTANCE methods
// of external classes with an additional named `object` (HTExternalMethod).
// Declaring all three satisfies both typedefs.
const String _closureSig =
    '({dynamic object, List<dynamic> positionalArgs = const [], Map<String, dynamic> namedArgs = const {}})';

String _display(DartType t) {
  // ignore: deprecated_member_use
  var s = t.getDisplayString(withNullability: true);
  return s;
}

String _displayNonNull(DartType t) {
  var s = _display(t);
  if (s.endsWith('?')) s = s.substring(0, s.length - 1);
  return s;
}

bool _isVoidLike(DartType t) {
  final s = _display(t);
  return s == 'void' || s == 'dynamic' || s == 'Null' || s.startsWith('Future<');
}

/// Wraps a raw dynamic expression according to the target parameter type:
/// - function types: adapt an incoming HTFunction into a Dart closure of the
///   right shape (hetu invokes external functions with named
///   positionalArgs/namedArgs only — see hetu external_function.dart);
/// - double: hetu numbers may arrive as int, coerce via num.toDouble();
/// - List<T>: script lists are List<dynamic>, rebuild as List<T>.
String convertArgExpr(DartType type, String raw) {
  final nullable = _display(type).endsWith('?');
  if (type is FunctionType) return _callbackExpr(type, raw);
  if (type.isDartCoreDouble) {
    return nullable
        ? '(($raw) as num?)?.toDouble()'
        : '(($raw) as num).toDouble()';
  }
  if (type.isDartCoreList && type is InterfaceType) {
    final args = type.typeArguments;
    if (args.length == 1) {
      final inner = _displayNonNull(args[0]);
      if (inner != 'dynamic' && inner != 'Object') {
        return nullable
            ? '($raw) == null ? null : List<$inner>.from($raw)'
            : 'List<$inner>.from(($raw) ?? const [])';
      }
    }
  }
  return raw;
}

String _callbackExpr(FunctionType ft, String raw) {
  // Only simple positional shapes are adapted; anything else passes through.
  if (ft.parameters.any((p) => p.isNamed) || ft.parameters.length > 2) {
    return raw;
  }
  final sigParams = <String>[];
  final callArgs = <String>[];
  for (var i = 0; i < ft.parameters.length; i++) {
    sigParams.add('${_display(ft.parameters[i].type)} a$i');
    callArgs.add('a$i');
  }
  final call =
      '(($raw) as HTFunction).call(positionalArgs: [${callArgs.join(', ')}])';
  final String closure;
  if (_isVoidLike(ft.returnType)) {
    closure = '(${sigParams.join(', ')}) { $call; }';
  } else {
    closure =
        '(${sigParams.join(', ')}) => $call as ${_display(ft.returnType)}';
  }
  return '($raw) == null ? null : (($raw) is HTFunction ? $closure : ($raw))';
}

// NOTE on defaults: when the .ht declaration carries a full parameter list,
// hetu normalizes the call and passes null for every argument the script did
// not supply — so "was it passed" must be detected via null, not containsKey.
String _positionalExpr(ParameterElement p, int i) {
  final raw = 'positionalArgs[$i]';
  final converted = convertArgExpr(p.type, raw);
  if (p.hasDefaultValue && p.defaultValueCode != null) {
    return '(positionalArgs.length > $i && $raw != null) ? $converted : ${p.defaultValueCode}';
  }
  // A required parameter with a typed (non-nullable) conversion cannot fall
  // back to null — index directly; omitting it is a script-side error anyway.
  final nonNullableTyped = !_display(p.type).endsWith('?') &&
      (p.type.isDartCoreDouble || p.type.isDartCoreList);
  if (nonNullableTyped) return converted;
  return 'positionalArgs.length > $i ? $converted : null';
}

String _namedExpr(ParameterElement p) {
  final raw = "namedArgs['${p.name}']";
  final converted = convertArgExpr(p.type, raw);
  if (p.hasDefaultValue && p.defaultValueCode != null) {
    return '${p.name}: $raw == null ? ${p.defaultValueCode} : $converted';
  }
  return '${p.name}: $converted';
}

String _argList(List<ParameterElement> parameters) {
  final parts = <String>[];
  var positionalIndex = 0;
  for (final p in parameters) {
    if (p.isPositional) {
      parts.add(_positionalExpr(p, positionalIndex));
      positionalIndex++;
    } else {
      parts.add(_namedExpr(p));
    }
  }
  return parts.join(', ');
}

/// Emits the HTExternalClass + htFetch/htAssign extension for [clazz] into
/// [buffer]; returns the manifest of the emitted surface.
ClassManifest emitClassBinding(ClassElement clazz, StringBuffer buffer,
    {EmitOptions options = const EmitOptions()}) {
  final className = clazz.name;
  final manifest = ClassManifest(className);

  buffer.writeln('// *** hetu_script_generator output for $className');
  buffer.writeln('class ${className}ClassBinding extends HTExternalClass {');
  buffer.writeln("  ${className}ClassBinding() : super('$className');");

  // ---- memberGet: constructors + statics -------------------------------
  buffer.writeln('');
  buffer.writeln('  @override');
  buffer.writeln(
      '  dynamic memberGet(String id, {String? from, bool isRecursive = false, bool ignoreUndefined = false}) {');
  buffer.writeln('    switch (id) {');

  for (final c in clazz.constructors) {
    if (c.isPrivate) continue;
    // Abstract classes can only be "constructed" through factories.
    if (clazz.isAbstract && !c.isFactory) continue;
    if (options.skipped(c.name.isEmpty ? className : c.name)) continue;
    final key = c.name.isEmpty ? className : '$className.${c.name}';
    final prefix = c.name.isEmpty ? className : '$className.${c.name}';
    buffer.writeln("      case '$key':");
    buffer.writeln(
        '        return $_closureSig => $prefix(${_argList(c.parameters)});');
    manifest.constructors.add((c.name, ParamSig.of(c.parameters)));
  }

  for (final method in clazz.methods) {
    if (!method.isStatic || method.isPrivate || method.isOperator) continue;
    if (options.skipped(method.name)) continue;
    buffer.writeln("      case '$className.${method.name}':");
    buffer.writeln(
        '        return $_closureSig => $className.${method.name}(${_argList(method.parameters)});');
    manifest.staticMethods.add((method.name, ParamSig.of(method.parameters)));
  }

  for (final field in clazz.fields) {
    if (!field.isStatic || field.isPrivate || field.isSynthetic) continue;
    if (options.skipped(field.name)) continue;
    buffer.writeln("      case '$className.${field.name}':");
    buffer.writeln('        return $className.${field.name};');
    manifest.staticGetters.add(field.name);
    if (!(field.isFinal || field.isConst)) {
      manifest.staticSetters.add(field.name);
    }
  }

  for (final acc in clazz.accessors) {
    if (!acc.isStatic || acc.isPrivate || !acc.isGetter) continue;
    final propName = acc.displayName;
    if (options.skipped(propName)) continue;
    if (clazz.fields.any((f) => !f.isSynthetic && f.name == propName)) continue;
    buffer.writeln("      case '$className.$propName':");
    buffer.writeln('        return $className.$propName;');
    manifest.staticGetters.add(propName);
  }

  buffer.writeln('      default:');
  buffer.writeln('        throw HTError.undefined(id);');
  buffer.writeln('    }');
  buffer.writeln('  }');

  // ---- memberSet: static assignment ------------------------------------
  buffer.writeln('');
  buffer.writeln('  @override');
  buffer.writeln(
      '  void memberSet(String id, dynamic value, {String? from, bool defineIfAbsent = false}) {');
  buffer.writeln('    switch (id) {');

  for (final field in clazz.fields) {
    if (!field.isStatic || field.isPrivate || field.isSynthetic) continue;
    if (options.skipped(field.name)) continue;
    buffer.writeln("      case '$className.${field.name}':");
    if (field.isFinal || field.isConst) {
      buffer.writeln('        throw HTError.immutable(id);');
    } else {
      buffer.writeln('        $className.${field.name} = value;');
      buffer.writeln('        break;');
    }
  }

  for (final acc in clazz.accessors) {
    if (!acc.isStatic || acc.isPrivate || !acc.isSetter) continue;
    final propName = acc.displayName.replaceAll('=', '');
    if (options.skipped(propName)) continue;
    if (clazz.fields.any((f) => !f.isSynthetic && f.name == propName)) continue;
    buffer.writeln("      case '$className.$propName':");
    buffer.writeln('        $className.$propName = value;');
    buffer.writeln('        break;');
    manifest.staticSetters.add(propName);
  }

  buffer.writeln('      default:');
  buffer.writeln('        throw HTError.undefined(id);');
  buffer.writeln('    }');
  buffer.writeln('  }');

  // ---- instance dispatch ------------------------------------------------
  buffer.writeln('');
  buffer.writeln('  @override');
  buffer.writeln(
      '  dynamic instanceMemberGet(dynamic instance, String id, {bool ignoreUndefined = false}) {');
  buffer.writeln('    try {');
  buffer.writeln('      return (instance as $className).htFetch(id);');
  buffer.writeln('    } on HTError {');
  buffer.writeln('      if (!ignoreUndefined) rethrow;');
  buffer.writeln('      return null;');
  buffer.writeln('    }');
  buffer.writeln('  }');

  buffer.writeln('');
  buffer.writeln('  @override');
  buffer.writeln(
      '  void instanceMemberSet(dynamic instance, String id, dynamic value, {bool ignoreUndefined = false}) {');
  buffer.writeln('    try {');
  buffer.writeln('      (instance as $className).htAssign(id, value);');
  buffer.writeln('    } on HTError {');
  buffer.writeln('      if (!ignoreUndefined) rethrow;');
  buffer.writeln('    }');
  buffer.writeln('  }');
  buffer.writeln('}');

  // ---- htFetch extension ------------------------------------------------
  buffer.writeln('');
  buffer.writeln('extension ${className}ObjectBinding on $className {');
  buffer.writeln('  dynamic htFetch(String varName) {');
  buffer.writeln('    switch (varName) {');
  buffer.writeln("      case 'runtimeType':");
  buffer.writeln("        return const HTExternalType('$className');");

  final emittedInstance = <String>{'runtimeType'};

  // StatefulWidget convenience: expose createState.
  if (_extendsFrom(clazz, 'StatefulWidget')) {
    buffer.writeln("      case 'createState':");
    buffer.writeln('        return $_closureSig => createState();');
    emittedInstance.add('createState');
    manifest.instanceMethods.add(('createState', ParamSig([], [], [])));
  }

  for (final method in clazz.methods) {
    if (method.isStatic || method.isPrivate || method.isAbstract) continue;
    if (method.isOperator) continue;
    if (options.skipped(method.name)) continue;
    if (!emittedInstance.add(method.name)) continue;
    buffer.writeln("      case '${method.name}':");
    buffer.writeln(
        '        return $_closureSig => ${method.name}(${_argList(method.parameters)});');
    manifest.instanceMethods.add((method.name, ParamSig.of(method.parameters)));
  }

  final instanceFields = _collectInstanceFields(clazz);
  final declaredInstanceFields = clazz.fields
      .where((f) => !f.isStatic && !f.isPrivate && !f.isSynthetic)
      .toList();
  final inheritedInstanceFields =
      instanceFields.where((f) => !declaredInstanceFields.contains(f)).toList();

  for (final field in [...declaredInstanceFields, ...inheritedInstanceFields]) {
    if (options.skipped(field.name)) continue;
    if (!emittedInstance.add(field.name)) continue;
    buffer.writeln("      case '${field.name}':");
    buffer.writeln('        return ${field.name};');
    manifest.instanceGetters.add(field.name);
  }

  final instanceAccessors = _collectInstanceAccessors(clazz);
  for (final entry in instanceAccessors.entries) {
    final propName = entry.key;
    if (options.skipped(propName)) continue;
    if (emittedInstance.contains(propName)) continue;
    final getterExists =
        entry.value['get']! && clazz.lookUpGetter(propName, clazz.library) != null;
    if (getterExists) {
      emittedInstance.add(propName);
      buffer.writeln("      case '$propName':");
      buffer.writeln('        return $propName;');
      manifest.instanceGetters.add(propName);
    }
  }

  buffer.writeln('      default:');
  buffer.writeln('        throw HTError.undefined(varName);');
  buffer.writeln('    }');
  buffer.writeln('  }');

  // ---- htAssign extension ----------------------------------------------
  buffer.writeln('');
  buffer.writeln('  void htAssign(String id, dynamic value) {');
  buffer.writeln('    switch (id) {');

  final emittedAssigns = <String>{};

  for (final field in clazz.fields) {
    if (field.isStatic || field.isPrivate || field.isSynthetic) continue;
    if (options.skipped(field.name)) continue;
    emittedAssigns.add(field.name);
    buffer.writeln("      case '${field.name}':");
    if (field.isFinal || field.isConst) {
      buffer.writeln('        throw HTError.immutable(id);');
    } else {
      buffer.writeln('        ${field.name} = value;');
      buffer.writeln('        break;');
      manifest.instanceSetters.add(field.name);
    }
  }

  for (final entry in instanceAccessors.entries) {
    final propName = entry.key;
    if (options.skipped(propName)) continue;
    if (emittedAssigns.contains(propName)) continue;

    final hasNonFinalBacking = instanceFields
        .any((f) => f.name == propName && !(f.isFinal || f.isConst));
    final setterElement = clazz.lookUpSetter(propName, clazz.library);
    final hasExplicitSetter = setterElement != null && !setterElement.isSynthetic;
    if (!(hasNonFinalBacking || hasExplicitSetter)) continue;

    FieldElement? backing;
    for (final f in instanceFields) {
      if (f.name == propName) {
        backing = f;
        break;
      }
    }
    if (backing != null && (backing.isFinal || backing.isConst)) {
      buffer.writeln("      case '$propName':");
      buffer.writeln('        throw HTError.immutable(id);');
      continue;
    }
    emittedAssigns.add(propName);
    buffer.writeln("      case '$propName':");
    buffer.writeln('        $propName = value;');
    buffer.writeln('        break;');
    manifest.instanceSetters.add(propName);
  }

  // Static-backed settable properties stay reachable through instances
  // (mirrors the historical hand-written binding behavior).
  for (final acc in clazz.accessors) {
    if (!acc.isStatic || acc.isPrivate || !acc.isSetter) continue;
    final propName = acc.displayName.replaceAll('=', '');
    if (options.skipped(propName)) continue;
    if (emittedAssigns.contains(propName)) continue;
    emittedAssigns.add(propName);
    buffer.writeln("      case '$propName':");
    final backing = clazz.fields.where((f) => f.name == propName).toList();
    if (backing.isNotEmpty && (backing.first.isFinal || backing.first.isConst)) {
      buffer.writeln('        throw HTError.immutable(id);');
    } else {
      buffer.writeln('        $className.$propName = value;');
      buffer.writeln('        break;');
    }
  }

  buffer.writeln('      default:');
  buffer.writeln('        throw HTError.undefined(id);');
  buffer.writeln('    }');
  buffer.writeln('  }');
  buffer.writeln('}');

  return manifest;
}

/// Emits the binding for an enum; exposes constants, `values`, and instance
/// `index`/`name`.
ClassManifest emitEnumBinding(EnumElement enumEl, StringBuffer buffer) {
  final enumName = enumEl.name;
  final manifest = ClassManifest(enumName, isEnum: true);

  buffer.writeln('// *** hetu_script_generator output for $enumName');
  buffer.writeln('class ${enumName}ClassBinding extends HTExternalClass {');
  buffer.writeln("  ${enumName}ClassBinding() : super('$enumName');");

  buffer.writeln('');
  buffer.writeln('  @override');
  buffer.writeln(
      '  dynamic memberGet(String id, {String? from, bool isRecursive = false, bool ignoreUndefined = false}) {');
  buffer.writeln('    switch (id) {');
  for (final f in enumEl.fields.where((f) => f.isEnumConstant)) {
    buffer.writeln("      case '$enumName.${f.name}':");
    buffer.writeln('        return $enumName.${f.name};');
    manifest.enumValues.add(f.name);
  }
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
  buffer.writeln('    throw HTError.immutable(id);');
  buffer.writeln('  }');

  buffer.writeln('');
  buffer.writeln('  @override');
  buffer.writeln(
      '  dynamic instanceMemberGet(dynamic instance, String id, {bool ignoreUndefined = false}) {');
  buffer.writeln('    try {');
  buffer.writeln('      return (instance as $enumName).htFetch(id);');
  buffer.writeln('    } on HTError {');
  buffer.writeln('      if (!ignoreUndefined) rethrow;');
  buffer.writeln('      return null;');
  buffer.writeln('    }');
  buffer.writeln('  }');
  buffer.writeln('}');

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
  buffer.writeln('}');

  return manifest;
}

List<FieldElement> _collectInstanceFields(ClassElement c) {
  final seen = <String>{};
  final out = <FieldElement>[];
  dynamic current = c.thisType;
  while (current != null && current.element.name != 'Object') {
    final curClass = current.element;
    for (final f in curClass.fields) {
      if (f.isStatic || f.isPrivate || f.isSynthetic) continue;
      if (seen.add(f.name)) out.add(f);
    }
    for (final mix in curClass.mixins) {
      for (final f in mix.element.fields) {
        if (f.isStatic || f.isPrivate || f.isSynthetic) continue;
        if (seen.add(f.name)) out.add(f);
      }
    }
    for (final intf in curClass.interfaces) {
      for (final f in intf.element.fields) {
        if (f.isStatic || f.isPrivate || f.isSynthetic) continue;
        if (seen.add(f.name)) out.add(f);
      }
    }
    final next = curClass.supertype;
    if (next == null) break;
    current = next;
  }
  return out;
}

Map<String, Map<String, bool>> _collectInstanceAccessors(ClassElement c) {
  final result = <String, Map<String, bool>>{};
  void register(dynamic acc) {
    if (acc.isStatic || acc.isPrivate) return;
    final name = acc.displayName.replaceAll('=', '');
    final map = result.putIfAbsent(name, () => {'get': false, 'set': false});
    if (acc.isGetter) map['get'] = true;
    if (acc.isSetter) map['set'] = true;
  }

  dynamic current = c.thisType;
  while (current != null && current.element.name != 'Object') {
    final curClass = current.element;
    for (final acc in curClass.accessors) {
      register(acc);
    }
    for (final mix in curClass.mixins) {
      for (final acc in mix.element.accessors) {
        register(acc);
      }
    }
    for (final intf in curClass.interfaces) {
      for (final acc in intf.element.accessors) {
        register(acc);
      }
    }
    final next = curClass.supertype;
    if (next == null) break;
    current = next;
  }
  return result;
}

bool _extendsFrom(ClassElement c, String baseName) {
  var sup = c.supertype;
  while (sup != null) {
    if (sup.element.name == baseName) return true;
    sup = sup.element.supertype;
  }
  return false;
}
