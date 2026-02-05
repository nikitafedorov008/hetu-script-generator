// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: public_member_api_docs, unnecessary_this, unused_import, prefer_void_to_null, deprecated_member_use_from_same_package

part of 'person.dart';

// **************************************************************************
// HetuBindingsGenerator
// **************************************************************************

// *** hetu_script_generator output for Person
class PersonClassBinding extends HTExternalClass {
  PersonClassBinding() : super('Person');

  @override
  dynamic memberGet(String id,
      {String? from, bool isRecursive = false, bool ignoreUndefined = false}) {
    switch (id) {
      case 'Person':
        return ({positionalArgs, namedArgs}) =>
            Person(positionalArgs.length > 0 ? positionalArgs[0] : null);
      default:
        throw HTError.undefined(id);
    }
  }

  @override
  void memberSet(String id, dynamic value,
      {String? from, bool defineIfAbsent = false}) {
    switch (id) {
      default:
        throw HTError.undefined(id);
    }
  }

  @override
  dynamic instanceMemberGet(dynamic instance, String id,
      {bool ignoreUndefined = false}) {
    try {
      return (instance as Person).htFetch(id);
    } on HTError catch (e) {
      if (!ignoreUndefined) rethrow;
      return null;
    }
  }

  @override
  void instanceMemberSet(dynamic instance, String id, dynamic value,
      {bool ignoreUndefined = false}) {
    try {
      var i = instance as Person;
      i.htAssign(id, value);
    } on HTError catch (e) {
      if (!ignoreUndefined) rethrow;
    }
  }
}

extension PersonObjectBinding on Person {
  dynamic htFetch(String varName) {
    switch (varName) {
      case 'runtimeType':
        return const HTExternalType('Person');
      case 'greet':
        return ({positionalArgs, namedArgs}) => greet();
      case 'name':
        return name;
      default:
        throw HTError.undefined(varName);
    }
  }

  void htAssign(String id, dynamic value) {
    switch (id) {
      case 'name':
        throw HTError.immutable(id);
      default:
        throw HTError.undefined(id);
    }
  }
}
