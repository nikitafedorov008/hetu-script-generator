import 'package:test/test.dart';

String _collapse(String s) => s.replaceAll(RegExp(r'\s+'), ' ');

/// Whitespace-insensitive containment: survives dart_style reformatting of
/// the generated output (line splits, indentation changes).
Matcher containsNormalized(List<String> pieces) => predicate<String>(
      (s) {
        final norm = _collapse(s);
        return pieces.every((p) => norm.contains(_collapse(p)));
      },
      'contains all pieces (whitespace-insensitive)',
    );

Matcher notContainsNormalized(List<String> pieces) => predicate<String>(
      (s) {
        final norm = _collapse(s);
        return pieces.every((p) => !norm.contains(_collapse(p)));
      },
      'contains none of the pieces (whitespace-insensitive)',
    );
