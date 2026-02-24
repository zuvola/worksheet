import 'dart:io';

import 'package:flutter/material.dart' hide BorderStyle;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/worksheet.dart';

/// Loads the four bundled Roboto font variants under the package-resolved name.
///
/// Must be called in `setUpAll()` before any golden test that renders text.
Future<void> loadGoldenFonts() async {
  final fontLoader = FontLoader('packages/worksheet/Roboto');
  for (final fileName in [
    'Roboto-Regular.ttf',
    'Roboto-Bold.ttf',
    'Roboto-Italic.ttf',
    'Roboto-BoldItalic.ttf',
  ]) {
    final fontData = File('assets/fonts/$fileName').readAsBytesSync();
    fontLoader.addFont(Future.value(ByteData.view(fontData.buffer)));
  }
  await fontLoader.load();
}

/// Sets the test surface size and DPR for consistent golden rendering.
Future<void> setupGoldenSurface(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
}

/// Resets the test surface size and DPR to defaults.
Future<void> resetGoldenSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(null);
  tester.view.resetPhysicalSize();
  tester.view.resetDevicePixelRatio();
}

/// Wraps a [Worksheet] in a standard MaterialApp → Scaffold → WorksheetTheme
/// tree suitable for golden tests.
Widget goldenWorksheetApp({
  required WorksheetData data,
  int rowCount = 100,
  int columnCount = 26,
  double defaultColumnWidth = 90,
  double defaultRowHeight = 30,
  Map<int, double>? customRowHeights,
  Map<int, double>? customColumnWidths,
  FreezeConfig freezeConfig = FreezeConfig.none,
  bool readOnly = false,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(fontFamily: 'Roboto'),
    home: Scaffold(
      body: WorksheetTheme(
        data: WorksheetThemeData(
          fontFamily: 'Roboto',
          defaultColumnWidth: defaultColumnWidth,
          defaultRowHeight: defaultRowHeight,
          rowHeaderWidth: 45,
          columnHeaderHeight: 30,
        ),
        child: Worksheet(
          data: data,
          rowCount: rowCount,
          columnCount: columnCount,
          customRowHeights: customRowHeights,
          customColumnWidths: customColumnWidths,
          freezeConfig: freezeConfig,
          readOnly: readOnly,
        ),
      ),
    ),
  );
}
