import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diplomacy_app/models/board_state.dart';

void main() {
  group('BoardState.provinceColors', () {
    test('paints a province in its owning empire\'s colour', () {
      final colors = BoardState.provinceColors(
        scOwnership: [
          {'province_code': 'par', 'empire_code': 'fra'},
        ],
        empires: [
          {'code': 'fra', 'color': '#0000FF'},
        ],
      );
      expect(colors['par'], const Color(0xFF0000FF).withOpacity(0.55));
    });

    test('skips rows with no colour for the owning empire', () {
      final colors = BoardState.provinceColors(
        scOwnership: [
          {'province_code': 'par', 'empire_code': 'fra'},
        ],
        empires: [],
      );
      expect(colors, isEmpty);
    });

    test('tolerates the empty lists a preview or bare history row sends', () {
      expect(BoardState.provinceColors(scOwnership: [], empires: []), {});
    });
  });

  group('BoardState.labelPositions', () {
    test('reads {code: [x, y]} into an Offset map', () {
      final positions = BoardState.labelPositions({
        'par': [10, 20],
      });
      expect(positions['par'], const Offset(10, 20));
    });

    test('degrades to empty rather than throwing when null', () {
      expect(BoardState.labelPositions(null), {});
    });
  });

  group('BoardState.unitPositionsAndColors', () {
    test('reads position and colour off each unit row', () {
      final (positions, colors) = BoardState.unitPositionsAndColors([
        {
          'province_code': 'par',
          'unit_x': 1,
          'unit_y': 2,
          'color': '#00FF00',
        },
      ]);
      expect(positions['par'], const Offset(1, 2));
      expect(colors['par'], const Color(0xFF00FF00));
    });

    test(
        'handles a preview\'s EmpireStartingUnit rows, which carry no '
        'is_mine and no id', () {
      final (positions, colors) = BoardState.unitPositionsAndColors([
        {'province_code': 'lon', 'unit_x': 5, 'unit_y': 6, 'color': '#FF0000'},
      ]);
      expect(positions['lon'], const Offset(5, 6));
      expect(colors['lon'], const Color(0xFFFF0000));
    });

    test('skips a row with no province_code rather than throwing', () {
      final (positions, colors) = BoardState.unitPositionsAndColors([
        {'unit_x': 1, 'unit_y': 2, 'color': '#FF0000'},
      ]);
      expect(positions, isEmpty);
      expect(colors, isEmpty);
    });
  });
}
