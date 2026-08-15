// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: public_member_api_docs, unnecessary_this, unused_import, prefer_void_to_null, deprecated_member_use_from_same_package, deprecated_member_use, unused_element, avoid_renaming_method_parameters, unnecessary_parenthesis, curly_braces_in_flow_control_structures, directives_ordering, prefer_is_empty

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
        return (
                {List<dynamic> positionalArgs = const [],
                Map<String, dynamic> namedArgs = const {}}) =>
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
    } on HTError {
      if (!ignoreUndefined) rethrow;
      return null;
    }
  }

  @override
  void instanceMemberSet(dynamic instance, String id, dynamic value,
      {bool ignoreUndefined = false}) {
    try {
      (instance as Person).htAssign(id, value);
    } on HTError {
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
        return (
                {List<dynamic> positionalArgs = const [],
                Map<String, dynamic> namedArgs = const {}}) =>
            greet();
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
        return (
                {List<dynamic> positionalArgs = const [],
                Map<String, dynamic> namedArgs = const {}}) =>
            Human(
                (positionalArgs.length > 0 && positionalArgs[0] != null)
                    ? positionalArgs[0]
                    : 'Jimmy',
                (positionalArgs.length > 1 && positionalArgs[1] != null)
                    ? positionalArgs[1]
                    : 'Caucasian');
      case 'Human.withName':
        return (
                {List<dynamic> positionalArgs = const [],
                Map<String, dynamic> namedArgs = const {}}) =>
            Human.withName(
                positionalArgs.length > 0 ? positionalArgs[0] : null,
                (positionalArgs.length > 1 && positionalArgs[1] != null)
                    ? positionalArgs[1]
                    : 'Caucasian');
      case 'Human.meaning':
        return (
                {List<dynamic> positionalArgs = const [],
                Map<String, dynamic> namedArgs = const {}}) =>
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
        Human.level = value;
        break;
      default:
        throw HTError.undefined(id);
    }
  }

  @override
  dynamic instanceMemberGet(dynamic instance, String id,
      {bool ignoreUndefined = false}) {
    try {
      return (instance as Human).htFetch(id);
    } on HTError {
      if (!ignoreUndefined) rethrow;
      return null;
    }
  }

  @override
  void instanceMemberSet(dynamic instance, String id, dynamic value,
      {bool ignoreUndefined = false}) {
    try {
      (instance as Human).htAssign(id, value);
    } on HTError {
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
        return (
                {List<dynamic> positionalArgs = const [],
                Map<String, dynamic> namedArgs = const {}}) =>
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
