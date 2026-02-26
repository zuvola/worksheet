import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/geometry/layout_solver.dart';
import 'package:worksheet/src/core/geometry/span_list.dart';
import 'package:worksheet/src/core/geometry/zoom_transformer.dart';
import 'package:worksheet/src/core/models/cell_coordinate.dart';
import 'package:worksheet/src/core/models/cell_range.dart';
import 'package:worksheet/src/rendering/tile/tile.dart';
import 'package:worksheet/src/rendering/tile/tile_config.dart';
import 'package:worksheet/src/rendering/tile/tile_coordinate.dart';
import 'package:worksheet/src/rendering/tile/tile_manager.dart';

/// Test tile renderer that creates simple test pictures.
class TestTileRenderer implements TileRenderer {
  int renderCallCount = 0;
  final List<TileCoordinate> renderedCoordinates = [];

  @override
  ui.Picture renderTile({
    required TileCoordinate coordinate,
    required ui.Rect bounds,
    required CellRange cellRange,
    required ZoomBucket zoomBucket,
  }) {
    renderCallCount++;
    renderedCoordinates.add(coordinate);

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawRect(bounds, ui.Paint()..color = const ui.Color(0xFFFFFFFF));
    return recorder.endRecording();
  }
}

void main() {
  group('TileManager', () {
    late LayoutSolver layoutSolver;
    late TileConfig config;
    late TestTileRenderer renderer;
    late TileManager manager;

    setUp(() {
      layoutSolver = LayoutSolver(
        rows: SpanList(count: 1000, defaultSize: 25.0),
        columns: SpanList(count: 100, defaultSize: 100.0),
      );
      config = const TileConfig(
        tileSize: 256,
        maxCachedTiles: 10,
        prefetchRings: 0,
      );
      renderer = TestTileRenderer();
      manager = TileManager(
        layoutSolver: layoutSolver,
        config: config,
        renderer: renderer,
      );
    });

    tearDown(() {
      manager.dispose();
    });

    group('construction', () {
      test('creates with required dependencies', () {
        expect(manager.config, config);
      });
    });

    group('getTilesForViewport', () {
      test('returns tiles covering viewport', () {
        final tiles = manager.getTilesForViewport(
          viewport: const ui.Rect.fromLTWH(0, 0, 512, 512),
          zoomBucket: ZoomBucket.full,
        );

        // 512x512 viewport with 256x256 tiles = 2x2 = 4 tiles
        expect(tiles.length, 4);
      });

      test('renders tiles on demand', () {
        manager.getTilesForViewport(
          viewport: const ui.Rect.fromLTWH(0, 0, 256, 256),
          zoomBucket: ZoomBucket.full,
        );

        expect(renderer.renderCallCount, 1);
      });

      test('caches rendered tiles', () {
        // First call renders
        manager.getTilesForViewport(
          viewport: const ui.Rect.fromLTWH(0, 0, 256, 256),
          zoomBucket: ZoomBucket.full,
        );
        expect(renderer.renderCallCount, 1);

        // Second call uses cache
        manager.getTilesForViewport(
          viewport: const ui.Rect.fromLTWH(0, 0, 256, 256),
          zoomBucket: ZoomBucket.full,
        );
        expect(renderer.renderCallCount, 1);
      });

      test('re-renders invalid tiles', () {
        manager.getTilesForViewport(
          viewport: const ui.Rect.fromLTWH(0, 0, 256, 256),
          zoomBucket: ZoomBucket.full,
        );
        expect(renderer.renderCallCount, 1);

        // Invalidate
        manager.invalidateAll();

        // Should re-render
        manager.getTilesForViewport(
          viewport: const ui.Rect.fromLTWH(0, 0, 256, 256),
          zoomBucket: ZoomBucket.full,
        );
        expect(renderer.renderCallCount, 2);
      });

      test('handles viewport larger than single tile', () {
        final tiles = manager.getTilesForViewport(
          viewport: const ui.Rect.fromLTWH(0, 0, 1024, 512),
          zoomBucket: ZoomBucket.full,
        );

        // 1024x512 with 256x256 tiles = 4x2 = 8 tiles
        expect(tiles.length, 8);
      });

      test('handles offset viewport', () {
        final tiles = manager.getTilesForViewport(
          viewport: const ui.Rect.fromLTWH(128, 128, 256, 256),
          zoomBucket: ZoomBucket.full,
        );

        // Viewport spans 4 tiles (partial coverage)
        expect(tiles.length, 4);
      });
    });

    group('getTileCoordinatesForViewport', () {
      test('returns tile coordinates for viewport', () {
        final coords = manager.getTileCoordinatesForViewport(
          viewport: const ui.Rect.fromLTWH(0, 0, 512, 512),
        );

        expect(coords.length, 4);
        expect(coords, contains(TileCoordinate(0, 0)));
        expect(coords, contains(TileCoordinate(0, 1)));
        expect(coords, contains(TileCoordinate(1, 0)));
        expect(coords, contains(TileCoordinate(1, 1)));
      });
    });

    group('invalidateRange', () {
      test('invalidates tiles covering range', () {
        // Pre-render tiles
        manager.getTilesForViewport(
          viewport: const ui.Rect.fromLTWH(0, 0, 512, 512),
          zoomBucket: ZoomBucket.full,
        );
        final initialCount = renderer.renderCallCount;

        // Invalidate a cell range
        manager.invalidateRange(CellRange(0, 0, 5, 5));

        // Re-fetch - some tiles should re-render
        manager.getTilesForViewport(
          viewport: const ui.Rect.fromLTWH(0, 0, 512, 512),
          zoomBucket: ZoomBucket.full,
        );

        expect(renderer.renderCallCount, greaterThan(initialCount));
      });
    });

    group('invalidateZoomBucket', () {
      test('invalidates tiles for specific zoom bucket', () {
        // Render tiles at full zoom
        manager.getTilesForViewport(
          viewport: const ui.Rect.fromLTWH(0, 0, 256, 256),
          zoomBucket: ZoomBucket.full,
        );
        final countAfterFirst = renderer.renderCallCount;

        // Invalidate full zoom bucket
        manager.invalidateZoomBucket(ZoomBucket.full);

        // Re-fetch at full zoom should re-render
        manager.getTilesForViewport(
          viewport: const ui.Rect.fromLTWH(0, 0, 256, 256),
          zoomBucket: ZoomBucket.full,
        );
        expect(renderer.renderCallCount, greaterThan(countAfterFirst));
      });
    });

    group('invalidateAll', () {
      test('invalidates all cached tiles', () {
        manager.getTilesForViewport(
          viewport: const ui.Rect.fromLTWH(0, 0, 256, 256),
          zoomBucket: ZoomBucket.full,
        );
        final countAfterFirst = renderer.renderCallCount;

        manager.invalidateAll();

        manager.getTilesForViewport(
          viewport: const ui.Rect.fromLTWH(0, 0, 256, 256),
          zoomBucket: ZoomBucket.full,
        );
        expect(renderer.renderCallCount, greaterThan(countAfterFirst));
      });
    });

    group('clearCache', () {
      test('removes all cached tiles', () {
        manager.getTilesForViewport(
          viewport: const ui.Rect.fromLTWH(0, 0, 256, 256),
          zoomBucket: ZoomBucket.full,
        );
        final countAfterFirst = renderer.renderCallCount;

        manager.clearCache();

        // Re-fetch should render new tiles
        manager.getTilesForViewport(
          viewport: const ui.Rect.fromLTWH(0, 0, 256, 256),
          zoomBucket: ZoomBucket.full,
        );
        expect(renderer.renderCallCount, greaterThan(countAfterFirst));
      });
    });

    group('getCellRangeForTile', () {
      test('calculates cell range for tile', () {
        final range = manager.getCellRangeForTile(
          TileCoordinate(0, 0),
          ZoomBucket.full,
        );

        // Tile 0,0 at full zoom covers pixel 0-256, 0-256
        // With 100px columns and 25px rows:
        // Columns: 0-256 = cols 0-2 (3 columns)
        // Rows: 0-256 = rows 0-10 (11 rows)
        expect(range.startRow, 0);
        expect(range.startColumn, 0);
      });

      test('calculates cell range for offset tile', () {
        final range = manager.getCellRangeForTile(
          TileCoordinate(1, 1),
          ZoomBucket.full,
        );

        // Tile 1,1 at full zoom covers pixel 256-512, 256-512
        expect(range.startRow, greaterThan(0));
        expect(range.startColumn, greaterThan(0));
      });
    });

    group('getTile', () {
      test('returns cached tile if valid', () {
        final key = TileKey(TileCoordinate(0, 0), ZoomBucket.full);

        // Render tile
        manager.getTilesForViewport(
          viewport: const ui.Rect.fromLTWH(0, 0, 256, 256),
          zoomBucket: ZoomBucket.full,
        );

        final tile = manager.getTile(key);
        expect(tile, isNotNull);
        expect(tile!.isValid, isTrue);
      });

      test('returns null for missing tile', () {
        final key = TileKey(TileCoordinate(100, 100), ZoomBucket.full);
        expect(manager.getTile(key), isNull);
      });
    });

    group('dispose', () {
      test('disposes cache', () {
        manager.getTilesForViewport(
          viewport: const ui.Rect.fromLTWH(0, 0, 256, 256),
          zoomBucket: ZoomBucket.full,
        );

        manager.dispose();

        // Accessing after dispose should still work (creates new tiles)
        // but internal state is cleared
      });
    });

    group('column resize cell coverage', () {
      // These tests verify that after a column resize, every visible cell
      // is covered by at least one tile's cell range (no gaps).

      late LayoutSolver resizeSolver;
      late TileManager resizeManager;
      late TestTileRenderer resizeRenderer;

      setUp(() {
        // Use example-app dimensions: 20px rows, 64px columns
        resizeSolver = LayoutSolver(
          rows: SpanList(count: 100, defaultSize: 20.0),
          columns: SpanList(count: 26, defaultSize: 64.0),
        );
        resizeRenderer = TestTileRenderer();
        resizeManager = TileManager(
          layoutSolver: resizeSolver,
          config: const TileConfig(tileSize: 256, maxCachedTiles: 50),
          renderer: resizeRenderer,
        );
      });

      tearDown(() {
        resizeManager.dispose();
      });

      /// Returns all (row, col) pairs covered by at least one tile's
      /// cell range for the given viewport.
      Set<(int, int)> getCoveredCells(ui.Rect viewport) {
        final coords = resizeManager.getTileCoordinatesForViewport(
          viewport: viewport,
        );
        final covered = <(int, int)>{};
        for (final coord in coords) {
          final range = resizeManager.getCellRangeForTile(
            coord,
            ZoomBucket.full,
          );
          for (int r = range.startRow; r <= range.endRow; r++) {
            for (int c = range.startColumn; c <= range.endColumn; c++) {
              covered.add((r, c));
            }
          }
        }
        return covered;
      }

      /// Returns the set of (row, col) pairs that are geometrically
      /// visible in the viewport, based on the layout solver.
      Set<(int, int)> getExpectedVisibleCells(ui.Rect viewport) {
        final rowRange = resizeSolver.getVisibleRows(
          viewport.top,
          viewport.height,
        );
        final colRange = resizeSolver.getVisibleColumns(
          viewport.left,
          viewport.width,
        );
        final expected = <(int, int)>{};
        for (int r = rowRange.startIndex; r <= rowRange.endIndex; r++) {
          for (int c = colRange.startIndex; c <= colRange.endIndex; c++) {
            expected.add((r, c));
          }
        }
        return expected;
      }

      test('all visible cells covered before resize', () {
        const viewport = ui.Rect.fromLTWH(0, 0, 800, 600);
        final covered = getCoveredCells(viewport);
        final expected = getExpectedVisibleCells(viewport);

        // Every expected cell should be covered by a tile
        for (final cell in expected) {
          expect(
            covered,
            contains(cell),
            reason: 'Cell (${cell.$1}, ${cell.$2}) not covered',
          );
        }
      });

      test('all visible cells covered after widening column 0', () {
        const viewport = ui.Rect.fromLTWH(0, 0, 800, 600);

        // Resize column 0 from 64px to 150px
        resizeSolver.setColumnWidth(0, 150.0);
        resizeManager.invalidateAll();

        final covered = getCoveredCells(viewport);
        final expected = getExpectedVisibleCells(viewport);

        for (final cell in expected) {
          expect(
            covered,
            contains(cell),
            reason: 'Cell (${cell.$1}, ${cell.$2}) not covered after resize',
          );
        }
      });

      test('all visible cells covered after narrowing column 0', () {
        const viewport = ui.Rect.fromLTWH(0, 0, 800, 600);

        // Resize column 0 from 64px to 25px (near minimum)
        resizeSolver.setColumnWidth(0, 25.0);
        resizeManager.invalidateAll();

        final covered = getCoveredCells(viewport);
        final expected = getExpectedVisibleCells(viewport);

        for (final cell in expected) {
          expect(
            covered,
            contains(cell),
            reason: 'Cell (${cell.$1}, ${cell.$2}) not covered after narrow',
          );
        }
      });

      test(
        'all visible cells covered after widening column wider than tile',
        () {
          const viewport = ui.Rect.fromLTWH(0, 0, 800, 600);

          // Make column 0 wider than a tile (300px > 256px)
          resizeSolver.setColumnWidth(0, 300.0);
          resizeManager.invalidateAll();

          final covered = getCoveredCells(viewport);
          final expected = getExpectedVisibleCells(viewport);

          for (final cell in expected) {
            expect(
              covered,
              contains(cell),
              reason: 'Cell (${cell.$1}, ${cell.$2}) not covered (wide col)',
            );
          }
        },
      );

      test('all visible cells covered after multiple column resizes', () {
        const viewport = ui.Rect.fromLTWH(0, 0, 800, 600);

        // Simulate incremental drag resize (multiple small changes)
        for (var width = 64.0; width <= 200.0; width += 5.0) {
          resizeSolver.setColumnWidth(2, width);
          resizeManager.invalidateAll();
        }

        final covered = getCoveredCells(viewport);
        final expected = getExpectedVisibleCells(viewport);

        for (final cell in expected) {
          expect(
            covered,
            contains(cell),
            reason:
                'Cell (${cell.$1}, ${cell.$2}) not covered after '
                'incremental resize',
          );
        }
      });

      test('cells at tile boundaries are intersect-checked correctly', () {
        // Resize column 0 so that cells straddle tile boundaries
        // (offset columns from tile grid alignment)
        resizeSolver.setColumnWidth(0, 100.0);
        resizeManager.invalidateAll();

        const tileSize = 256.0;

        // Check tiles along the first row
        for (var tileCol = 0; tileCol < 4; tileCol++) {
          final tileBounds = ui.Rect.fromLTWH(
            tileCol * tileSize,
            0,
            tileSize,
            tileSize,
          );
          final coord = TileCoordinate(0, tileCol);
          final range = resizeManager.getCellRangeForTile(
            coord,
            ZoomBucket.full,
          );

          // Every cell in the range should geometrically intersect
          // the tile bounds
          for (int r = range.startRow; r <= range.endRow; r++) {
            for (int c = range.startColumn; c <= range.endColumn; c++) {
              final cellBounds = resizeSolver.getCellBounds(
                CellCoordinate(r, c),
              );
              final localLeft = cellBounds.left - tileBounds.left;
              final localTop = cellBounds.top - tileBounds.top;

              // Replicate _boundsIntersect check
              final intersects =
                  localLeft < tileSize &&
                  localLeft + cellBounds.width > 0 &&
                  localTop < tileSize &&
                  localTop + cellBounds.height > 0;

              expect(
                intersects,
                isTrue,
                reason:
                    'Cell ($r, $c) in tile (0, $tileCol) range but '
                    'does not intersect tile bounds',
              );
            }
          }
        }
      });

      test('tiles re-render all viewport tiles after invalidateAll', () {
        const viewport = ui.Rect.fromLTWH(0, 0, 800, 600);

        // Initial render
        resizeManager.getTilesForViewport(
          viewport: viewport,
          zoomBucket: ZoomBucket.full,
        );
        final renderCount1 = resizeRenderer.renderCallCount;

        // Resize and invalidate
        resizeSolver.setColumnWidth(0, 150.0);
        resizeManager.invalidateAll();

        // Re-render
        final tiles2 = resizeManager.getTilesForViewport(
          viewport: viewport,
          zoomBucket: ZoomBucket.full,
        );
        final renderCount2 = resizeRenderer.renderCallCount;

        // All viewport tiles should have been re-rendered
        expect(renderCount2 - renderCount1, equals(tiles2.length));

        // All returned tiles should be valid
        for (final tile in tiles2) {
          expect(tile.isValid, isTrue);
        }
      });
    });

    group('prefetching', () {
      late LayoutSolver prefetchSolver;

      setUp(() {
        prefetchSolver = LayoutSolver(
          rows: SpanList(count: 1000, defaultSize: 25.0),
          columns: SpanList(count: 100, defaultSize: 100.0),
        );
      });

      test('prefetchRings=1 fetches tiles beyond viewport', () {
        final prefetchRenderer = TestTileRenderer();
        final prefetchManager = TileManager(
          layoutSolver: prefetchSolver,
          config: const TileConfig(
            tileSize: 256,
            maxCachedTiles: 50,
            prefetchRings: 1,
          ),
          renderer: prefetchRenderer,
        );

        // 1-tile viewport at (256,256) → with 1 ring prefetch, should get 3×3 = 9 tiles
        final tiles = prefetchManager.getTilesForViewport(
          viewport: const ui.Rect.fromLTWH(256, 256, 256, 256),
          zoomBucket: ZoomBucket.full,
        );

        expect(tiles.length, 9);
        prefetchManager.dispose();
      });

      test('prefetchRings=0 fetches only visible tiles', () {
        final prefetchRenderer = TestTileRenderer();
        final prefetchManager = TileManager(
          layoutSolver: prefetchSolver,
          config: const TileConfig(
            tileSize: 256,
            maxCachedTiles: 50,
            prefetchRings: 0,
          ),
          renderer: prefetchRenderer,
        );

        // Same 1-tile viewport, no prefetch → 1 tile
        final tiles = prefetchManager.getTilesForViewport(
          viewport: const ui.Rect.fromLTWH(256, 256, 256, 256),
          zoomBucket: ZoomBucket.full,
        );

        expect(tiles.length, 1);
        prefetchManager.dispose();
      });

      test('prefetch at origin clamps to non-negative', () {
        final prefetchRenderer = TestTileRenderer();
        final prefetchManager = TileManager(
          layoutSolver: prefetchSolver,
          config: const TileConfig(
            tileSize: 256,
            maxCachedTiles: 50,
            prefetchRings: 1,
          ),
          renderer: prefetchRenderer,
        );

        // Viewport at origin — prefetch inflates to negative coords
        final tiles = prefetchManager.getTilesForViewport(
          viewport: const ui.Rect.fromLTWH(0, 0, 256, 256),
          zoomBucket: ZoomBucket.full,
        );

        // All tile coordinates should be non-negative
        for (final tile in tiles) {
          expect(tile.coordinate.row, greaterThanOrEqualTo(0));
          expect(tile.coordinate.column, greaterThanOrEqualTo(0));
        }

        // Should get 2×2 = 4 tiles (origin + 1 ring, clamped at 0)
        expect(tiles.length, 4);
        prefetchManager.dispose();
      });

      test('prefetched tiles are cached', () {
        final prefetchRenderer = TestTileRenderer();
        final prefetchManager = TileManager(
          layoutSolver: prefetchSolver,
          config: const TileConfig(
            tileSize: 256,
            maxCachedTiles: 50,
            prefetchRings: 1,
          ),
          renderer: prefetchRenderer,
        );

        prefetchManager.getTilesForViewport(
          viewport: const ui.Rect.fromLTWH(256, 256, 256, 256),
          zoomBucket: ZoomBucket.full,
        );
        final firstCallCount = prefetchRenderer.renderCallCount;

        // Second call with same viewport — all tiles should be cached
        prefetchManager.getTilesForViewport(
          viewport: const ui.Rect.fromLTWH(256, 256, 256, 256),
          zoomBucket: ZoomBucket.full,
        );
        expect(prefetchRenderer.renderCallCount, firstCallCount);
        prefetchManager.dispose();
      });

      test('scrolling into prefetched area uses cache', () {
        final prefetchRenderer = TestTileRenderer();
        final prefetchManager = TileManager(
          layoutSolver: prefetchSolver,
          config: const TileConfig(
            tileSize: 256,
            maxCachedTiles: 50,
            prefetchRings: 1,
          ),
          renderer: prefetchRenderer,
        );

        // Fetch at origin with 1 ring prefetch
        prefetchManager.getTilesForViewport(
          viewport: const ui.Rect.fromLTWH(0, 0, 256, 256),
          zoomBucket: ZoomBucket.full,
        );
        final firstCallCount = prefetchRenderer.renderCallCount;

        // Scroll one tile to the right — tile (0,1) should already be cached
        prefetchManager.getTilesForViewport(
          viewport: const ui.Rect.fromLTWH(256, 0, 256, 256),
          zoomBucket: ZoomBucket.full,
        );

        // The now-visible tile (0,1) was prefetched, but we also prefetch
        // a new ring around the new viewport. Only truly new tiles should render.
        // Tile (0,0) was cached, tile (0,1) was prefetched, tile (0,2) is new.
        // Row 1 tiles: (1,0) cached, (1,1) prefetched, (1,2) new.
        // So only tiles in the new ring that weren't in the old ring should render.
        expect(prefetchRenderer.renderCallCount, greaterThan(firstCallCount));

        // But it should be LESS than rendering all tiles from scratch
        // (some tiles were already cached from prefetch)
        final newRenders = prefetchRenderer.renderCallCount - firstCallCount;
        final totalTilesInSecondCall = 9; // 3×3 with prefetch
        expect(newRenders, lessThan(totalTilesInSecondCall));
        prefetchManager.dispose();
      });
    });

    group('boundary tile clamping', () {
      test('tile beyond content height gets minimal cell range', () {
        // With 1000 rows × 25px = 25000px total height, tile size 256,
        // the last tile row within content is floor(25000 / 256) = 97.
        // Tile 98 starts at 98 * 256 = 25088 which is beyond totalHeight (25000).
        final range = manager.getCellRangeForTile(
          TileCoordinate(98, 0),
          ZoomBucket.full,
        );

        // startRow should clamp to maxRow (999), not 0
        expect(range.startRow, equals(999));
        expect(range.endRow, equals(999));
        // Should cover only 1 row, not the entire sheet
        expect(range.endRow - range.startRow, lessThanOrEqualTo(1));
      });

      test('tile beyond content width gets minimal cell range', () {
        // With 100 cols × 100px = 10000px total width, tile size 256,
        // the last tile column within content is floor(10000 / 256) = 39.
        // Tile 40 starts at 40 * 256 = 10240 which is beyond totalWidth (10000).
        final range = manager.getCellRangeForTile(
          TileCoordinate(0, 40),
          ZoomBucket.full,
        );

        // startCol should clamp to maxCol (99), not 0
        expect(range.startColumn, equals(99));
        expect(range.endColumn, equals(99));
        // Should cover only 1 column, not the entire sheet
        expect(range.endColumn - range.startColumn, lessThanOrEqualTo(1));
      });

      test('tile at content boundary has correct range', () {
        // Tile at the very last row of content
        // totalHeight = 25000, last pixel position = 24999
        // Tile row = floor(24999 / 256) = 97
        final range = manager.getCellRangeForTile(
          TileCoordinate(97, 0),
          ZoomBucket.full,
        );

        // Should cover some rows near the end, not the entire sheet
        expect(range.startRow, greaterThan(900));
        expect(range.endRow, equals(999));
        expect(range.endRow - range.startRow, lessThan(20));
      });

      test('tile at Excel scale beyond content does not freeze', () {
        // Simulate Excel-scale: 1M+ rows
        final excelSolver = LayoutSolver(
          rows: SpanList(count: 1048576, defaultSize: 24.0),
          columns: SpanList(count: 16384, defaultSize: 100.0),
        );
        final excelManager = TileManager(
          layoutSolver: excelSolver,
          config: config,
          renderer: renderer,
        );

        // totalHeight = 1048576 * 24 = 25165824
        // Tile at exactly totalHeight / 256 = 98304
        final sw = Stopwatch()..start();
        final range = excelManager.getCellRangeForTile(
          TileCoordinate(98304, 0),
          ZoomBucket.full,
        );
        sw.stop();

        // Should be clamped to last row, not spanning entire sheet
        expect(range.startRow, equals(1048575));
        expect(range.endRow, equals(1048575));
        // Should be instant (< 1ms), not 6+ seconds
        expect(sw.elapsedMilliseconds, lessThan(10));

        excelManager.dispose();
      });
    });
  });
}
