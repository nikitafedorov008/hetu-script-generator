/// Annotations used by the `hetu_script_generator`.
///
/// Keep these lightweight and const so they can be used at compile-time.
library hetu_script_generator.annotations;

/// Marks a class for which Hetu external binding should be generated.
class HetuExternalClass {
  final String? name;
  const HetuExternalClass([this.name]);
}

/// Marks a member to be included/excluded or renamed in the generated binding.
class HetuExternalMember {
  final bool include;
  final String? rename;
  final bool ignore;
  const HetuExternalMember(
      {this.include = true, this.rename, this.ignore = false});
}

/// Marks a top-level function for generation.
class HetuExternalFunction {
  const HetuExternalFunction();
}

/// File-level directive to enable generation for the whole file.
class HetuGenerateBindings {
  const HetuGenerateBindings();
}

// Public re-exports (future API growth)
const hetuExternalClass = HetuExternalClass;
const hetuExternalMember = HetuExternalMember;
const hetuExternalFunction = HetuExternalFunction;
const hetuGenerateBindings = HetuGenerateBindings;
