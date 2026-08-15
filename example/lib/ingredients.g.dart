// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: public_member_api_docs, unnecessary_this, unused_import, prefer_void_to_null, deprecated_member_use_from_same_package, deprecated_member_use, unused_element, avoid_renaming_method_parameters, unnecessary_parenthesis, curly_braces_in_flow_control_structures, directives_ordering, prefer_is_empty

part of 'ingredients.dart';

// **************************************************************************
// HetuBindingsGenerator
// **************************************************************************

// *** hetu_script_generator output for Ingredients
class IngredientsClassBinding extends HTExternalClass {
  IngredientsClassBinding() : super('Ingredients');

  @override
  dynamic memberGet(String id,
      {String? from, bool isRecursive = false, bool ignoreUndefined = false}) {
    switch (id) {
      case 'Ingredients.Apple':
        return Ingredients.Apple;
      case 'Ingredients.Banana':
        return Ingredients.Banana;
      case 'Ingredients.Cinnamon':
        return Ingredients.Cinnamon;
      case 'Ingredients.values':
        return Ingredients.values;
      default:
        throw HTError.undefined(id);
    }
  }

  @override
  void memberSet(String id, dynamic value,
      {String? from, bool defineIfAbsent = false}) {
    throw HTError.immutable(id);
  }

  @override
  dynamic instanceMemberGet(dynamic instance, String id,
      {bool ignoreUndefined = false}) {
    try {
      return (instance as Ingredients).htFetch(id);
    } on HTError {
      if (!ignoreUndefined) rethrow;
      return null;
    }
  }
}

extension IngredientsObjectBinding on Ingredients {
  dynamic htFetch(String varName) {
    switch (varName) {
      case 'runtimeType':
        return const HTExternalType('Ingredients');
      case 'index':
        return index;
      case 'name':
        return name;
      default:
        throw HTError.undefined(varName);
    }
  }
}
