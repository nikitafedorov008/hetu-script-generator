// Small runtime helpers and common ignore lists used by the generator and
// by generated files.

const generatedHeader = '''// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: public_member_api_docs, unnecessary_this, unused_import, prefer_void_to_null, deprecated_member_use_from_same_package
''';

String makePartOf(String sourceFile) => "part of '$sourceFile';\n\n";
