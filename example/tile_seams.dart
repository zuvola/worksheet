import 'package:flutter/material.dart';
import 'package:worksheet/worksheet.dart';

/// White worksheet on a black background for visually testing tile seam
/// artifacts at various zoom levels.
///
/// Run from the example/ directory:
///   flutter run -t tile_seams.dart -d chrome
void main() => runApp(const MaterialApp(home: TileSeamsTest()));

class TileSeamsTest extends StatefulWidget {
  const TileSeamsTest({super.key});

  @override
  State<TileSeamsTest> createState() => _TileSeamsTestState();
}

class _TileSeamsTestState extends State<TileSeamsTest> {
  late final SparseWorksheetData _data;
  late final WorksheetController _controller;
  double _zoom = 1.0;

  @override
  void initState() {
    super.initState();
    _data = SparseWorksheetData(rowCount: 200, columnCount: 50);
    _controller = WorksheetController();
  }

  @override
  void dispose() {
    _controller.dispose();
    _data.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Tile Seams Test — ${(_zoom * 100).toStringAsFixed(0)}%'),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
        actions: [
          for (final z in [0.5, 0.6, 0.7, 0.75, 0.85, 1.0, 1.5, 2.0, 3.0, 4.0])
            TextButton(
              onPressed: () {
                setState(() {
                  _zoom = z;
                  _controller.setZoom(z);
                });
              },
              child: Text(
                '${(z * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  color: _zoom == z ? Colors.amber : Colors.white70,
                  fontWeight: _zoom == z ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: WorksheetTheme(
          data: const WorksheetThemeData(),
          child: Worksheet(
            data: _data,
            controller: _controller,
            rowCount: _data.rowCount,
            columnCount: _data.columnCount,
          ),
        ),
      ),
    );
  }
}
