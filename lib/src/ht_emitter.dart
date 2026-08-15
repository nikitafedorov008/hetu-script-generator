// Renders the Hetu-side `external class` declarations from the manifests
// produced by the Dart emitter, so both sides of the binding contract stay
// in sync by construction.
import 'emitter.dart';

String emitHtDeclarations(List<ClassManifest> manifests) {
  final buf = StringBuffer();
  buf.writeln('// GENERATED CODE - DO NOT MODIFY BY HAND');
  buf.writeln('// Hetu declarations paired with the generated Dart bindings.');
  buf.writeln('');

  for (final m in manifests) {
    buf.writeln('external class ${m.name} {');
    if (m.isEnum) {
      for (final v in m.enumValues) {
        buf.writeln('    static get $v');
      }
      buf.writeln('    static get values');
      buf.writeln('    get index');
      buf.writeln('    get name');
    } else {
      for (final (name, sig) in m.constructors) {
        // hetu validates call arguments against the declaration, so emit the
        // real parameter list. (A bare `construct` would also swallow the
        // following `construct` keyword — always write explicit parens.)
        buf.writeln(name.isEmpty
            ? '    construct${sig.toHt()}'
            : '    construct $name${sig.toHt()}');
      }
      for (final (name, sig) in m.staticMethods) {
        buf.writeln('    static fun $name${sig.toHt()}');
      }
      final staticSetters = m.staticSetters.toSet();
      for (final g in m.staticGetters) {
        if (staticSetters.contains(g)) {
          buf.writeln('    static get $g');
          buf.writeln('    static set $g(value)');
        } else {
          buf.writeln('    static get $g');
        }
      }
      for (final s in staticSetters.where((s) => !m.staticGetters.contains(s))) {
        buf.writeln('    static set $s(value)');
      }
      for (final (name, sig) in m.instanceMethods) {
        buf.writeln('    fun $name${sig.toHt()}');
      }
      final instanceSetters = m.instanceSetters.toSet();
      for (final g in m.instanceGetters) {
        if (instanceSetters.contains(g)) {
          buf.writeln('    var $g');
        } else {
          buf.writeln('    get $g');
        }
      }
      for (final s
          in instanceSetters.where((s) => !m.instanceGetters.contains(s))) {
        buf.writeln('    set $s(value)');
      }
    }
    buf.writeln('}');
    buf.writeln('');
  }
  return buf.toString();
}
