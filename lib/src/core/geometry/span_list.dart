import 'dart:typed_data';

/// Efficient cumulative size storage for O(log n) position lookups.
///
/// SpanList stores row or column sizes and maintains a Fenwick tree
/// (Binary Indexed Tree) for fast position-to-index and index-to-position
/// conversions. Updates are O(log n) instead of O(n).
class SpanList {
  /// The number of spans (rows or columns).
  final int count;

  /// The default size for spans without custom sizes.
  final double defaultSize;

  /// Individual sizes for each span.
  final List<double> _sizes;

  /// Fenwick tree (1-indexed, length count + 1) for prefix sums.
  late Float64List _tree;

  /// Cached total size of all spans.
  late double _totalSize;

  /// Highest power-of-2 <= count, used for Fenwick descent.
  late int _highestBit;

  /// Creates a span list with the given [count] and [defaultSize].
  ///
  /// Optionally provide [customSizes] to override sizes at specific indices.
  SpanList({
    required this.count,
    required this.defaultSize,
    Map<int, double>? customSizes,
  }) : assert(count > 0, 'Count must be positive'),
       assert(defaultSize > 0, 'Default size must be positive'),
       _sizes = List<double>.filled(count, defaultSize) {
    // Apply custom sizes
    if (customSizes != null) {
      for (final entry in customSizes.entries) {
        if (entry.key >= 0 && entry.key < count) {
          _sizes[entry.key] = entry.value;
        }
      }
    }

    _buildTree();
  }

  /// Builds the Fenwick tree from _sizes in O(N) time.
  void _buildTree() {
    _tree = Float64List(count + 1);
    for (int i = 1; i <= count; i++) {
      _tree[i] += _sizes[i - 1];
      final parent = i + (i & (-i));
      if (parent <= count) _tree[parent] += _tree[i];
    }
    _totalSize = _prefixSum(count);
    _highestBit = 1;
    while (_highestBit * 2 <= count) {
      _highestBit *= 2;
    }
  }

  /// Returns the prefix sum of the first [i] elements (sum of _sizes[0..i-1]).
  double _prefixSum(int i) {
    var sum = 0.0;
    var idx = i;
    while (idx > 0) {
      sum += _tree[idx];
      idx -= idx & (-idx);
    }
    return sum;
  }

  /// Point-updates the Fenwick tree when _sizes[index] changes by [delta].
  void _update(int index, double delta) {
    var idx = index + 1; // 1-indexed
    while (idx <= count) {
      _tree[idx] += delta;
      idx += idx & (-idx);
    }
  }

  /// Returns the size of the span at [index].
  ///
  /// Throws [RangeError] if index is out of bounds.
  double sizeAt(int index) {
    RangeError.checkValidIndex(index, _sizes);
    return _sizes[index];
  }

  /// Returns the position (offset from start) where span [index] begins.
  ///
  /// [index] can be from 0 to count inclusive. Index == count returns totalSize.
  /// Throws [RangeError] if index is out of bounds.
  double positionAt(int index) {
    RangeError.checkValueInInterval(index, 0, count, 'index');
    return _prefixSum(index);
  }

  /// Returns the index of the span containing [position].
  ///
  /// Uses Fenwick tree descent for O(log n) performance.
  /// Returns -1 if position is negative or >= totalSize.
  int indexAtPosition(double position) {
    if (position < 0 || position >= _totalSize) {
      return -1;
    }

    // Fenwick descent: find largest index whose prefix sum <= position
    var idx = 0;
    var remaining = position;
    var bitMask = _highestBit;
    while (bitMask > 0) {
      final next = idx + bitMask;
      if (next <= count && _tree[next] <= remaining) {
        remaining -= _tree[next];
        idx = next;
      }
      bitMask >>= 1;
    }

    return idx;
  }

  /// Sets the size of the span at [index] and updates the Fenwick tree.
  ///
  /// O(log n) — only updates affected tree nodes.
  /// Throws [RangeError] if index is out of bounds.
  /// Throws [AssertionError] if size is not positive.
  void setSize(int index, double size) {
    RangeError.checkValidIndex(index, _sizes);
    assert(size > 0, 'Size must be positive');

    final delta = size - _sizes[index];
    _sizes[index] = size;
    _update(index, delta);
    _totalSize += delta;
  }

  /// The total size of all spans.
  double get totalSize => _totalSize;

  /// Returns the range of indices that intersect with the given position range.
  SpanRange getRange(double startPosition, double endPosition) {
    final startIndex = indexAtPosition(startPosition);
    final endIndex = indexAtPosition(endPosition - 0.001);

    // Clamp to valid range
    final clampedStart = startIndex < 0 ? 0 : startIndex;
    final clampedEnd = endIndex < 0 ? count - 1 : endIndex;

    return SpanRange(clampedStart, clampedEnd);
  }
}

/// A range of span indices.
class SpanRange {
  /// The starting index (inclusive).
  final int startIndex;

  /// The ending index (inclusive).
  final int endIndex;

  const SpanRange(this.startIndex, this.endIndex);

  /// The number of indices in this range.
  int get length => endIndex - startIndex + 1;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SpanRange &&
        other.startIndex == startIndex &&
        other.endIndex == endIndex;
  }

  @override
  int get hashCode => Object.hash(startIndex, endIndex);

  @override
  String toString() => 'SpanRange($startIndex, $endIndex)';
}
