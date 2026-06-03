/// High-performance Flutter worksheet widget with Excel-like functionality.
///
/// Supports 10%-400% zoom with GPU-optimized tile-based rendering.
library;

// A1 cell reference parsing (re-exported for custom FormulaReferenceAdjuster)
export 'package:a1/a1.dart' show A1, A1Range, A1Reference;

// Date parsing (re-exported so consumers don't need a direct any_date dependency)
export 'package:any_date/any_date.dart' show AnyDate, DateParserInfo;

// Core (models, geometry, data, formula)
export 'src/core/core.dart';

// Rendering (tile system, painters, layers)
export 'src/rendering/rendering.dart';

// Scrolling
export 'src/scrolling/scroll_anchor.dart';
export 'src/scrolling/scroll_physics.dart';
export 'src/scrolling/viewport_delegate.dart';
export 'src/scrolling/worksheet_scroll_delegate.dart';
export 'src/scrolling/worksheet_viewport.dart';

// Interaction (controllers, hit testing, clipboard, undo, gestures)
export 'src/interaction/interaction.dart';

// Widgets
export 'src/widgets/autocomplete_dropdown.dart';
export 'src/widgets/cell_editor_overlay.dart';
export 'src/widgets/formula_bar.dart';
export 'src/widgets/worksheet_controller.dart';
export 'src/widgets/worksheet_scrollbar_config.dart';
export 'src/widgets/worksheet_theme.dart';
export 'src/widgets/worksheet_widget.dart';

// Shortcuts / Actions
export 'src/shortcuts/shortcuts.dart';
