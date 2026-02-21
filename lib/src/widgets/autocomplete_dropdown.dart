import 'package:flutter/widgets.dart';

import '../core/formula/formula_autocomplete_config.dart';

/// Dropdown widget displaying formula autocomplete suggestions.
///
/// Renders a [ListView] of matching functions with bold prefix highlighting
/// and muted signatures. Uses [Listener] for tap detection to avoid stealing
/// focus from the editing [EditableText].
class AutocompleteDropdown extends StatelessWidget {
  /// The list of matching functions to display.
  final List<FormulaFunction> matches;

  /// The currently selected index.
  final int selectedIndex;

  /// The typed prefix used for bold highlighting in function names.
  final String prefix;

  /// Called when a function is selected (tapped).
  final void Function(FormulaFunction fn) onSelect;

  /// Maximum visible items before the dropdown scrolls.
  final int maxVisibleItems;

  /// Height of each item in the dropdown.
  static const double itemHeight = 32.0;

  /// Background color for the selected item.
  static const Color selectedColor = Color(0xFFE8F0FE);

  /// Background color for the dropdown.
  static const Color backgroundColor = Color(0xFFFFFFFF);

  /// Border color for the dropdown.
  static const Color borderColor = Color(0xFFDADCE0);

  /// Text color for the function name.
  static const Color nameColor = Color(0xFF202124);

  /// Text color for the signature.
  static const Color signatureColor = Color(0xFF5F6368);

  const AutocompleteDropdown({
    super.key,
    required this.matches,
    required this.selectedIndex,
    required this.prefix,
    required this.onSelect,
    this.maxVisibleItems = 8,
  });

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) return const SizedBox.shrink();

    final visibleCount =
        matches.length < maxVisibleItems ? matches.length : maxVisibleItems;
    final height = visibleCount * itemHeight;

    return Container(
      height: height,
      constraints: const BoxConstraints(maxWidth: 400),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [
          BoxShadow(
            color: Color(0x29000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: matches.length,
        itemExtent: itemHeight,
        itemBuilder: (context, index) {
          final fn = matches[index];
          final isSelected = index == selectedIndex;
          return _AutocompleteItem(
            function: fn,
            isSelected: isSelected,
            prefix: prefix,
            onTap: () => onSelect(fn),
          );
        },
      ),
    );
  }
}

class _AutocompleteItem extends StatelessWidget {
  final FormulaFunction function;
  final bool isSelected;
  final String prefix;
  final VoidCallback onTap;

  const _AutocompleteItem({
    required this.function,
    required this.isSelected,
    required this.prefix,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Build the function name with bold prefix highlighting
    final name = function.name;
    final prefixLen = prefix.length.clamp(0, name.length);
    final boldPart = name.substring(0, prefixLen);
    final normalPart = name.substring(prefixLen);

    return Listener(
      onPointerUp: (_) => onTap(),
      child: Container(
        height: AutocompleteDropdown.itemHeight,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AutocompleteDropdown.selectedColor
              : AutocompleteDropdown.backgroundColor,
        ),
        child: Row(
          children: [
            // Function name with bold prefix
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: boldPart,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AutocompleteDropdown.nameColor,
                    ),
                  ),
                  TextSpan(
                    text: normalPart,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.normal,
                      color: AutocompleteDropdown.nameColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Signature in muted text
            Expanded(
              child: Text(
                function.signature,
                style: const TextStyle(
                  fontSize: 12,
                  color: AutocompleteDropdown.signatureColor,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
