# PowerShell Module Semantic Versioning Specification

## Introduction

This document defines how changes to a PowerShell module’s public interface determine updates to its version number under Semantic Versioning (SemVer). Semantic Versioning uses a three-part version format: **MAJOR.MINOR.PATCH**, where each part is incremented based on the nature of changes:

- **MAJOR** version is incremented for incompatible API changes (breaking changes) ([Semantic Versioning 2.0.0 | Semantic Versioning](https://semver.org/#:~:text=Given%20a%20version%20number%20MAJOR,increment%20the)).
- **MINOR** version is incremented for added functionality that is backward compatible (new features) ([Semantic Versioning 2.0.0 | Semantic Versioning](https://semver.org/#:~:text=Given%20a%20version%20number%20MAJOR,increment%20the)).
- **PATCH** version is incremented for backward-compatible bugfixes or minor improvements ([Semantic Versioning 2.0.0 | Semantic Versioning](https://semver.org/#:~:text=Given%20a%20version%20number%20MAJOR,increment%20the)).

In the context of a PowerShell module, the “public API” consists of all exported functions/cmdlets, public variables, classes, and enums that consumers of the module can use. Changes to these exported elements will dictate whether the version bump is major, minor, or patch. Internal changes that do not affect the exported interface are generally not reflected in the version. The following sections categorize changes and the required version update level, ensuring a consistent and predictable versioning strategy.

## Major Version (X) – Breaking Changes

A **major version bump** signifies a breaking change in the module’s public interface. Any modification that could cause existing scripts or code relying on the module to fail or change behavior in an incompatible way requires incrementing the MAJOR version. These include:

- **Removal or Renaming of Exported Commands or Elements**: Removing an exported function/cmdlet, variable, class, or enum, or renaming any of these, is a breaking change. Consumers referencing the old name will encounter errors because the item no longer exists or has a different name. *(Example: `Get-ItemFoo` was exported in the previous version but is removed or renamed to `Get-FooItem` in the new version. Scripts calling `Get-ItemFoo` will break.)* This kind of change must increment the major version to signal the break.

- **Changes to Function Signatures**: Modifying the signature of an exported function or cmdlet in a non-backward-compatible way triggers a major bump. This includes:
  - Removing a parameter from a function.
  - Renaming a parameter (existing scripts using the old parameter name would fail).
  - Changing the type of a parameter or the return type in a way that could break callers.
  - Changing a parameter from optional to mandatory (or otherwise altering a default value in a way that requires callers to change how they call the function).
  - Reordering parameters **if** it affects how the function is invoked positionally (though in PowerShell named parameters are common, positional changes can break scripts that rely on positional invocation).
  - Any other modification to a function’s definition that would make previously valid calls invalid. For example, if a new parameter is added *without* a default and thus is required, it would break calls that don’t provide that parameter – this is a breaking change requiring a major version update ([semantic versioning - Does adding a parameter to a function definition require a new major version? - Stack Overflow](https://stackoverflow.com/questions/31678403/does-adding-a-parameter-to-a-function-definition-require-a-new-major-version#:~:text=,compatible%20bug%20fixes)) ([semantic versioning - Does adding a parameter to a function definition require a new major version? - Stack Overflow](https://stackoverflow.com/questions/31678403/does-adding-a-parameter-to-a-function-definition-require-a-new-major-version#:~:text=,compatible%20bug%20fixes)). (If the new parameter is optional, see Minor changes below.)

  *Example:* An exported function `Invoke-ProcessData -Path <string>` is changed to `Invoke-ProcessData -Uri <string>` (parameter renamed) or an existing parameter is removed. Scripts using the old parameter name or expecting that parameter will fail, hence a major version increment is needed.

- **Breaking Changes to Exported Classes**: If the module exports PowerShell classes (public classes meant for users to consume), any breaking change to those classes requires a major version bump. Breaking class changes include:
  - Removing a public class or renaming a class.
  - Removing or renaming public properties or methods of a class.
  - Changing the signature of a class method (e.g. altering parameters or return type in an incompatible way).
  - Changing property types or making a formerly public member non-public.

  *Example:* An exported class `FileClient` had a public property `Timeout` that is removed or renamed, or a method `Connect(string server)` is changed to `Connect(Uri server)`. Code instantiating `FileClient` or calling its methods would break, so the major version must increase.

- **Breaking Changes to Exported Enums**: Enums (enumerations) define a set of constant values. Changing them in a breaking way includes:
  - Removing an enum type that was exported.
  - Renaming an enum type or an enum member.
  - Removing an existing value from an enum, or altering its name or meaning.
  - Changing the underlying type of an enum (if relevant in PowerShell, e.g. from int to another type).

  *Example:* An exported enum `LogLevel` had members `Info, Warning, Error`. If `Warning` is removed or renamed to `Warn`, any script using `LogLevel.Warning` will break. Such a change mandates a major version bump. (Adding a new enum value is not breaking – see Minor changes.)

- **Other Incompatible Changes**: Any other change that alters the expected behavior or contract of the public API in a way that existing consumers would need to modify their code is considered breaking. For instance, if the module’s behavior changes in an incompatible manner (like a function now throws an error in a scenario where it previously quietly succeeded, or an output format changes such that scripts parsing the output would fail), the change should be treated as a breaking change. In general, **any removal or incompatible modification of functionality is a major change**.

**Rationale:** According to Semantic Versioning, introducing changes that are not backward compatible requires a major version increment ([Semantic Versioning 2.0.0 | Semantic Versioning](https://semver.org/#:~:text=Given%20a%20version%20number%20MAJOR,increment%20the)). By increasing the major version, we communicate to users that they may need to adjust their scripts due to breaking changes. This aligns with the principle that *“MAJOR version when you make incompatible API changes”* ([Semantic Versioning 2.0.0 | Semantic Versioning](https://semver.org/#:~:text=Given%20a%20version%20number%20MAJOR,increment%20the)). For example, if a function or parameter that existed in version 1.x is no longer present in version 2.0, that is an incompatible API change. Our versioning policy follows this rule strictly: breaking changes will never be introduced in a minor or patch release, ensuring that patch and minor updates can be safely adopted without fear of script-breaking surprises.

## Minor Version (Y) – Backward-Compatible Additions

A **minor version bump** is used for new features and additions that are backward compatible with the existing public API. These changes enhance the module’s functionality without breaking any existing usage. In other words, existing scripts will continue to work as before, and new capabilities are introduced. Changes that trigger a MINOR version increase include:

- **Adding New Exported Functions/Cmdlets**: Introducing a new function or cmdlet to the module is a backward-compatible addition. Since it does not remove or change existing functions, nothing breaks; users simply have an additional function available. *Example:* Adding a new cmdlet `New-Report` to the module (where it didn’t exist before) would be a new feature. This warrants a minor version bump because it’s an additive, non-breaking change.

- **Adding New Parameters to Existing Functions**: If you extend an existing function’s capabilities by adding a new parameter **in a way that does not break existing calls**, it is a minor change. The key here is that the new parameter must be optional or have a default value such that any existing calls (which don’t pass this parameter) still work exactly as before. In semantic versioning terms, this is adding functionality in a backwards-compatible manner ([semantic versioning - Does adding a parameter to a function definition require a new major version? - Stack Overflow](https://stackoverflow.com/questions/31678403/does-adding-a-parameter-to-a-function-definition-require-a-new-major-version#:~:text=If%20your%20extra%20param%20is,requires%20a%20MAJOR%20version%20change)).
  - If the new parameter is optional (or has a sensible default), existing scripts can ignore it and will not be affected ([semantic versioning - Does adding a parameter to a function definition require a new major version? - Stack Overflow](https://stackoverflow.com/questions/31678403/does-adding-a-parameter-to-a-function-definition-require-a-new-major-version#:~:text=If%20your%20extra%20param%20is,requires%20a%20MAJOR%20version%20change)). For example, adding an optional `-Force` switch or an optional `-TimeoutSeconds` parameter (with a default value) to a function is a minor update. Users can start using the new parameter if they want the new behavior, but all old usages remain valid.
  - **Important:** If a new parameter is added as *required* (with no default), that breaks existing calls (which would now be missing a required argument), and thus **would** be a breaking change requiring a major bump ([semantic versioning - Does adding a parameter to a function definition require a new major version? - Stack Overflow](https://stackoverflow.com/questions/31678403/does-adding-a-parameter-to-a-function-definition-require-a-new-major-version#:~:text=,compatible%20bug%20fixes)). So, new parameters must be introduced in a backward-compatible way (optional or with defaults) to qualify as a minor version update.

- **Adding New Exported Variables**: If the module begins to export a new public variable (for example, a new preference variable or a constant) that wasn’t present before, it’s an additive change. Since no existing variable is removed or changed, existing scripts are unaffected (they simply might not use or know about the new variable). This constitutes a minor version increment. *Example:* Adding a new `$PublicConfig` variable that scripts can read is a new feature, bumped in the minor version.

- **Adding New Classes or Members**: Introducing a new public class (exported from the module) or adding new members to an existing exported class in a non-breaking way is a minor change:
  - Adding a brand new class (e.g., a helper class or a new type for users to utilize) doesn’t impact existing code since nothing is removed or changed.
  - Adding a new method or property to an existing exported class can be considered backward compatible *as long as it doesn’t conflict with existing members*. Existing scripts constructing or using the class will continue to work as before. (One caveat: if consumers have derived from this class, adding new abstract members would be breaking, but assuming typical usage where classes are used as-is, new members are just additional features.)
  *Example:* A class `Connection` gains a new method `TestConnection()` in version 1.2. Previous scripts using `Connection` are not affected (they don’t call the new method), but now have the option to use `TestConnection`. This is a minor feature addition.

- **Adding New Enum Values or New Enums**: If the module introduces a new enumeration type, or adds additional members to an existing enum, it’s generally treated as a backward-compatible addition:
  - **New Enum Type:** Completely new enum (e.g., a new enum `Color` with values Red/Green/Blue) is additive.
  - **New Value in Existing Enum:** Adding a value to an existing exported enum can be viewed as a new feature. Code that doesn’t know about the new value isn’t forced to use it. (Existing switch statements or logic that enumerate enum values may not account for it, but they won’t immediately break at runtime; however, developers should update their code to handle the new case if appropriate. Since it doesn’t outright break compilation or invocation in PowerShell, it’s considered backward compatible in this context.)
  *Example:* The enum `LogLevel` had `Info, Warning, Error`. If we add `Verbose` as a new level in a minor release, existing scripts using `LogLevel` continue to run (they might not handle `Verbose` if encountered, but nothing crashes by the mere presence of the new value). It’s an additive feature, hence a minor bump.

- **Non-Breaking Changes to Existing Features**: In some cases, a change might alter behavior but still be backward compatible. For instance, making an existing parameter accept a new type of input in addition to existing types (broadening what is accepted) could be considered a new capability that doesn’t break old usage. Such changes can fall under minor version if they extend functionality without removal or contradiction of the old behavior. *(However, caution is advised: changing behavior can sometimes surprise users. If in doubt, treat as major if it might disrupt assumptions.)*

In summary, **any new functionality that does not force existing users to change their usage is a candidate for a minor version increment** ([Semantic Versioning 2.0.0 | Semantic Versioning](https://semver.org/#:~:text=Given%20a%20version%20number%20MAJOR,increment%20the)). Minor releases accumulate enhancements and new features, signalling to users that new capabilities are available, but all existing scripts should continue to work as they did in the previous version. Users can upgrade to the new minor version and gain new functions or options without needing to modify their existing code. This aligns with the SemVer guideline that *“MINOR version [increments] when you add functionality in a backward compatible manner”* ([Semantic Versioning 2.0.0 | Semantic Versioning](https://semver.org/#:~:text=Given%20a%20version%20number%20MAJOR,increment%20the)).

## Patch Version (Z) – Bugfixes and Improvements

A **patch version bump** is used for changes that do not affect the module's public API or add new features, but rather fix issues or improve internal implementation. Patch updates are meant to be safe, drop-in updates for users, with no risk of breaking functionality or changing how features are used. Scenarios for a PATCH version increment include:

- **Bugfixes**: Correcting any bugs in existing functions or features, provided the fix does not alter the function's signature or expected input/output in a way that would break compatibility. The behavior might change (from incorrect to correct), but since the original behavior was unintended (a bug), this is considered a backward-compatible fix. For example:
  - Fixing a logic error in a function so that it now produces the correct result.
  - Correcting a typo in output or an error message.
  - Resolving a minor issue where an enum value wasn’t handled in an internal function (assuming no public API change).
  As long as the outward-facing contract remains the same (same function name, parameters, outputs), these are patch changes. Consumers might notice the bug is resolved, but they do not need to change their code – they just get the benefit of the fix.

- **Performance Improvements**: Optimizations that improve the performance or efficiency of the module without affecting the external behavior or API. For instance, rewriting an algorithm inside a function to run faster or use less memory, but with the same input/output interface and results, qualifies as a patch. Users’ experience may improve (faster execution), but they don’t need to change anything in their usage. This is a non-breaking internal improvement.

- **Refactoring and Internal Cleanup**: Changes to the internal code structure, organization, or quality that do not change any aspect of the public interface or observable behavior fall under patch (or possibly no version change at all – see the next section). If you release a new version that purely refactors code (improves maintainability, updates comments, reorganizes module files) and the module’s exported functions and behavior remain identical, it can be considered a patch update. From the user’s perspective, nothing changed functionally, so there’s no new feature (hence not a minor) and no break (hence not a major). Releasing it as a patch version indicates it’s a minor improvement or maintenance release.

- **Documentation or Metadata Updates**: If you publish a new version to update documentation included in the module (e.g., help content) or to adjust module metadata (like author info, tags, etc.) without any code change affecting functionality, this would be a patch version increment. (However, often documentation changes alone might not necessitate a new release; if they do, patch is appropriate since the API is unchanged.)

**Note:** A patch release should not introduce any new public surface area or change the meaning of anything in the public API. It is strictly for fixes and invisible improvements. According to SemVer rules, *"PATCH version when you make backwards-compatible bugfixes"* ([Semantic Versioning 2.0.0 | Semantic Versioning](https://semver.org/#:~:text=Given%20a%20version%20number%20MAJOR,increment%20the)) – this includes fixes and minor tweaks that do not affect compatibility. Users upgrading from one patch version to the next within the same minor series (e.g., 1.2.3 to 1.2.4) should notice no differences except the resolved issues or performance gains. They do not get new features (and thus don't need to learn anything new), and they do not have to worry about breaks.

## Internal Changes with No Version Impact

Certain changes do not require any version number increase at all, because they have no effect on the module’s outward-facing behavior or interface. In a disciplined development practice, if the only changes in a commit or release are purely internal and produce no difference in functionality or API, the version can remain the same. In practice, such changes are often bundled with other changes or released as patch versions if needed. But as a guideline, **metadata or refactoring changes that do not impact the exported interface should not influence the version number** (they are essentially “no-ops” as far as the user is concerned). Examples:

- **Refactoring without Behavioral Changes**: If the code is refactored (e.g., splitting a large function into smaller private helper functions, renaming internal variables, improving readability) but the exported functions, classes, and variables all behave exactly the same and have the same signatures, then there’s no need for a version change. The module behaves identically from the consumer’s perspective.

- **Build tool or Test Changes**: Updates to the module's build scripts, continuous integration configuration, or test suite do not require a version bump. These are changes for the developers/maintainers and do not ship to the user in a way that affects usage.

- **Metadata Updates**: Changing non-functional metadata such as author name, project URL, licensing info, etc., in the module manifest (PSD1) doesn’t affect how the module is used at runtime. Such changes alone don’t merit a version increment.

- **Formatting and Comments**: Modifying code formatting, comments, or other non-executable parts of the code has no effect on functionality. No version change is needed for these kinds of modifications alone.

- **No-Op Rebuilds**: In some cases, a module might be rebuilt or repackaged without any code changes (for example, re-signing the module or packaging it differently). If the contents of the module’s public API and behavior are unchanged, the version number should ideally remain the same. (If a rebuild must be published, one might use the same version or a patch if required by tooling, but from a semantic standpoint, nothing changed.)

In summary, if a change does **not** modify or add to the public interface and does not fix a user-facing bug, it should not cause any visible version change. The automated versioning scripts or maintainers should ignore such changes when determining how to bump the version. Essentially, **purely internal changes = no bump** (or at most a patch if a release is needed for some reason). This ensures the version number reflects meaningful changes that users care about.

*(Note: In practice, every release must have a unique version. So if you are releasing changes that have no API impact, you might still increment the patch to publish it. But the key is that those internal changes by themselves never escalate the version beyond patch, and if they are truly no-ops, you might choose not to release until there’s a user-facing change.)*

## Versioning Strategy and Update Expectations

This module follows a **“latest version” support strategy**, meaning that only the most recent release is fully supported and maintained. When a new version is released, it supersedes previous versions. **Older versions are not maintained**, and users are expected to upgrade to the latest version to receive fixes and new features. As stated in Microsoft’s guidance for PowerShell modules: *“Only the latest major version receives full support, including new features, bugfixes, and updates. We strongly recommend upgrading to the latest version…”* ([Versioning, release cadence, and breaking changes - Microsoft Entra PowerShell | Microsoft Learn](https://learn.microsoft.com/en-us/powershell/entra-powershell/entraps-versioning-release-cadence?view=entra-powershell#:~:text=Only%20the%20latest%20major%20version,latest%20improvements%20and%20security%20updates)). In our context, this means:

- We do not create maintenance releases for older major versions. For example, if the module is currently at 2.x, we will not typically release further updates for 1.x; any fixes or enhancements will go into a new 2.x (or later) release. The focus is on moving forward with the latest version of the module.

- Breaking changes will be introduced only with a major version bump, and when we do increment the major version, users should plan to update their scripts to accommodate those changes. Since older majors won’t get back-ported fixes, upgrading is important to stay supported.

- Minor and patch releases are intended to be safe to adopt (no breaking changes). Users should feel confident updating to a new minor version within the same major series to get new features, and applying patch updates for bugfixes. Given that we don't maintain parallel old versions, applying these updates is the primary way to get issues resolved.

- Semantic versioning in this module serves as a contract with users: by looking at how the version changed, users can tell what to expect:
  - A major jump (e.g. 1.4.0 → 2.0.0) signals **“There are breaking changes; read the release notes and be prepared to adjust your usage.”**
  - A minor jump (e.g. 2.3.5 → 2.4.0) signals **“New features have been added, but everything you used before still works.”**
  - A patch jump (e.g. 2.4.0 → 2.4.1) signals **“No new features, but some issues were fixed or minor improvements made; nothing should break.”**

By adhering to this strategy, we ensure clarity and consistency. Users who always upgrade to the latest version will benefit from all improvements and will only need to make script changes when a major version increments (which will be clearly indicated by the version number change).

## Automated Version Bump Determination (Implementation)

To enforce the above rules, we will use custom PowerShell scripts as part of our build/release process to automatically determine the appropriate version bump based on the changes in the module. The automation will compare the module’s exported interface between the current release and the new version under development:

- It will **detect additions** of public elements (functions, parameters, variables, classes, enum values) and **detect removals or changes** to public elements.
- Based on this comparison, the script will decide the version increment:
  - If new public functions, new optional parameters, or other new exported members are found (and no breaking changes), the script will set the version bump to **Minor** (since new functionality has been added in a backwards-compatible way).
  - If any exported function/variable/class/enum from the previous version is missing in the new version, or a function’s signature has changed incompatibly, etc., the script will flag a **Major** bump (since a breaking change was detected).
  - If no differences in the public API are found (meaning no new features and no removed/changed features), then the changes must be purely fixes or internal improvements. In this case, the script will default to a **Patch** bump ([PowerShell: Automatic Module Semantic Versioning](https://powershellexplained.com/2017-10-14-Powershell-module-semantic-version/#:~:text=In%20this%20example%2C%20if%20there,version)).

This approach mirrors the “fingerprint” strategy: generating a list (fingerprint) of all public API elements (e.g., `FunctionName:ParameterName` for each parameter of each function, plus entries for other exported members) for the current and previous version, and comparing them ([PowerShell: Automatic Module Semantic Versioning](https://powershellexplained.com/2017-10-14-Powershell-module-semantic-version/#:~:text=%27Detecting%20new%20features%27%20%24fingerprint%20,)) ([PowerShell: Automatic Module Semantic Versioning](https://powershellexplained.com/2017-10-14-Powershell-module-semantic-version/#:~:text=In%20this%20example%2C%20if%20there,version)).

- If the new fingerprint has entries not present in the old fingerprint, those represent new capabilities (triggering a minor version increase) ([PowerShell: Automatic Module Semantic Versioning](https://powershellexplained.com/2017-10-14-Powershell-module-semantic-version/#:~:text=In%20this%20example%2C%20if%20there,version)).
- If the old fingerprint has entries not present in the new fingerprint, those represent removed or changed items (triggering a major version increase) ([PowerShell: Automatic Module Semantic Versioning](https://powershellexplained.com/2017-10-14-Powershell-module-semantic-version/#:~:text=In%20this%20example%2C%20if%20there,version)).
- If neither additions nor removals are detected, only patch-level changes exist ([PowerShell: Automatic Module Semantic Versioning](https://powershellexplained.com/2017-10-14-Powershell-module-semantic-version/#:~:text=In%20this%20example%2C%20if%20there,version)).

Using automation ensures that our versioning rules are applied consistently on every release. However, we will also manually review changes for any subtleties that automation might miss. For example, a change in behavior that is technically backward-compatible in the API surface might still be communicated as a bigger change if it could impact users (the automation might view it as no API change, but maintainers might still choose to bump minor for a significant new behavior or even major if a fix alters expected outcomes in rare cases). The tooling serves as a baseline, and maintainers can override or augment the decision if necessary (but always adhering to the rule that breaking changes cannot be released under a non-major bump).

**Example of the automated logic in practice:**
Suppose in version 1.3.0 the module has a function `Get-Data -Path <string>` and in the development code we change this to `Get-Data -Path <string> -Filter <string>`, where `-Filter` is a new optional parameter. The script compares the exported interface:

- Old version fingerprint might include an entry like `Get-Data:Path` for the parameter.
- New version fingerprint includes `Get-Data:Path` and `Get-Data:Filter`.
The new fingerprint has an entry not in the old (`Get-Data:Filter`), indicating a new parameter. The old fingerprint has none that the new lacks (we didn’t remove anything; `Path` is still there). So the tool will identify a new feature addition with no removals, resulting in a **Minor** bump (1.4.0). This matches our expectation: adding an optional `-Filter` parameter is a backward-compatible enhancement.

If instead we had removed `-Path` or renamed `Get-Data` to `Get-ItemData`, the old fingerprint would contain entries not in the new, flagging a breaking change. The script would then recommend a **Major** bump (to 2.0.0), aligning with our policy that such a removal/rename is breaking.

If we only fixed a bug inside `Get-Data` but made no changes to its parameters or outputs, the fingerprints would be identical. The automation would not find any new or removed public element, and thus default to a **Patch** bump (1.3.1). This ensures even unseen internal changes result in at least a patch update if a release is made, but nothing more.

## Conclusion

This specification provides a clear framework for versioning a PowerShell module in accordance with Semantic Versioning principles, tailored to the specific elements of a PowerShell module’s public interface. By classifying changes into major, minor, or patch categories, we ensure that the module’s version number accurately communicates the impact of changes:

- **Major** versions for breaking changes (removals, renames, incompatible alterations).
- **Minor** versions for new features and additions that are backward compatible.
- **Patch** versions for bugfixes and non-breaking improvements.

Developers maintaining the module can use these guidelines to decide the appropriate version number for each release. Automated scripts will assist in detecting the scope of changes, but sound judgment will be applied in edge cases. Users of the module can rely on the version number to understand the significance of an update. Ultimately, this practice enables a predictable upgrade path where users only need to be concerned about potential breaking changes when the major version increases, and are otherwise free to take minor and patch updates confidently.

By adhering to this specification, we uphold a contract of compatibility and improvement with our users, making module releases transparent and manageable in the long run.
