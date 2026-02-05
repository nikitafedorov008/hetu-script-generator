// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: public_member_api_docs, unnecessary_this, unused_import, prefer_void_to_null, deprecated_member_use_from_same_package

part of 'example.dart';

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

// *** hetu_script_generator output for Human
class HumanClassBinding extends HTExternalClass {
  HumanClassBinding() : super('Human');

  @override
  dynamic memberGet(String id,
      {String? from, bool isRecursive = false, bool ignoreUndefined = false}) {
    switch (id) {
      case 'Human':
        return ({positionalArgs, namedArgs}) => Human(
            positionalArgs.length > 0 ? positionalArgs[0] : 'Jimmy',
            positionalArgs.length > 1 ? positionalArgs[1] : 'Caucasion');
      case 'Human.withName':
        return ({positionalArgs, namedArgs}) => Human.withName(
            positionalArgs.length > 0 ? positionalArgs[0] : null,
            positionalArgs.length > 1 ? positionalArgs[1] : 'Caucasion');
      case 'Human.meaning':
        return ({positionalArgs, namedArgs}) =>
            Human.meaning(positionalArgs.length > 0 ? positionalArgs[0] : null);
      case 'Human.races':
        return Human.races;
      case 'Human.level':
        return Human.level;
      default:
        throw HTError.undefined(id);
    }
  }

  @override
  void memberSet(String id, dynamic value,
      {String? from, bool defineIfAbsent = false}) {
    switch (id) {
      case 'Human.races':
        throw HTError.immutable(id);
      case 'Human.level':
        return Human.level = value;
      default:
        throw HTError.undefined(id);
    }
  }

  @override
  dynamic instanceMemberGet(dynamic instance, String id,
      {bool ignoreUndefined = false}) {
    try {
      return (instance as Human).htFetch(id);
    } on HTError catch (e) {
      if (!ignoreUndefined) rethrow;
      return null;
    }
  }

  @override
  void instanceMemberSet(dynamic instance, String id, dynamic value,
      {bool ignoreUndefined = false}) {
    try {
      var i = instance as Human;
      i.htAssign(id, value);
    } on HTError catch (e) {
      if (!ignoreUndefined) rethrow;
    }
  }
}

extension HumanObjectBinding on Human {
  dynamic htFetch(String varName) {
    switch (varName) {
      case 'runtimeType':
        return const HTExternalType('Human');
      case 'greeting':
        return ({positionalArgs, namedArgs}) =>
            greeting(positionalArgs.length > 0 ? positionalArgs[0] : null);
      case 'name':
        return name;
      case 'race':
        return race;
      case 'child':
        return child;
      default:
        throw HTError.undefined(varName);
    }
  }

  void htAssign(String id, dynamic value) {
    switch (id) {
      case 'name':
        name = value;
        break;
      case 'race':
        race = value;
        break;
      case 'level':
        Human.level = value;
        break;
      default:
        throw HTError.undefined(id);
    }
  }
}
