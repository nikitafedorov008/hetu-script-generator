// Small runtime helpers and common ignore lists used by the generator and
// by generated files.

const generatedHeader = '''// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: public_member_api_docs, unnecessary_this, unused_import, prefer_void_to_null, deprecated_member_use_from_same_package, deprecated_member_use, unused_element, avoid_renaming_method_parameters, unnecessary_parenthesis, curly_braces_in_flow_control_structures, directives_ordering, prefer_is_empty, prefer_null_aware_operators, prefer_if_null_operators
''';

String makePartOf(String sourceFile) => "part of '$sourceFile';\n\n";
