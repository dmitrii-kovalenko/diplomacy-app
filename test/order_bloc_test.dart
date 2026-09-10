// Unit tests for OrderBloc's state machine (T17/T18 rework). 614 lines of
// state machine landed with every test on the pure reachability module and
// none on the bloc that drives it — these fill in the parts a differential
// comparison against orders_ui.js can't reach: how the bloc dispatches taps
// and narrows targets, not what counts as a legal target in isolation.
//
// Cases, and which defect each guards against regressing:
//  - support-aux narrowing: `_onSupportAuxTap` must intersect the aux unit's
//    own move targets with the supporter's reach, not just offer everything
//    the aux could move to.
//  - retreat's `occupied` filter: a retreat target list must exclude every
//    province a non-dislodged unit already sits on.
//  - pending-cancel dispatch: re-tapping a *different* province while
//    `pendingCancel`/`buildChoice` is showing for retreat or adjustment must
//    open that province's own menu, not sit inert until ✕ is pressed (the
//    fix for the "swallowed tap" defect — before it, only movement's
//    `unitSelected` was ever meant to block further taps).
//  - `coastOptionsFor`: a fleet move must only ever be offered a coast it
//    can actually enter from its current province (the STP/BAR defect the
//    judge's differential run couldn't see, since it's not part of
//    reachability.dart itself).
import 'dart:ui' show Path;

import 'package:flutter_test/flutter_test.dart';

import 'package:diplomacy_app/blocs/game/order_bloc.dart';
import 'package:diplomacy_app/widgets/map_viewer.dart';

/// A minimal land province, built the same way
/// test/reachability_test.dart's `_parseProvinces` would from an SVG node —
/// but hand-written here since these tests are about the bloc's dispatch,
/// not about any particular shipped map.
ProvinceData _land(String id, List<String> adj, {Map<String, List<String>> extraAdj = const {}}) {
  return ProvinceData(
    id: id,
    type: 'land',
    adjacencies: adj,
    path: Path(),
    cssClass: 'land',
    adjAttrs: {'data-adj': adj, ...extraAdj},
  );
}

Map<String, dynamic> _unit({
  required String province,
  int unitType = kUnitArmy,
  bool isMine = false,
  bool isDislodged = false,
  String coast = '',
}) {
  return {
    'province_code': province,
    'unit_type': unitType,
    'is_mine': isMine,
    'is_dislodged': isDislodged,
    'coast': coast,
  };
}

Map<String, dynamic> _order({
  required String source,
  required int orderType,
  String? target,
  int id = 1,
}) {
  return {
    'id': id,
    'source_code': source,
    'order_type': orderType,
    'order_type_name': 'Order',
    'target_code': target,
  };
}

Map<String, dynamic> _gameState({
  required List<Map<String, dynamic>> units,
  required int phaseKind,
  List<Map<String, dynamic>> myOrders = const [],
  List<Map<String, dynamic>> scOwnership = const [],
  int quota = 0,
  int phaseId = 1,
}) {
  return {
    'units': units,
    'my_orders': myOrders,
    'sc_ownership': scOwnership,
    'me': {'empire_code': 'ME', 'quota': quota},
    'phase': {'id': phaseId, 'kind': phaseKind},
  };
}

void main() {
  group('support-aux destination narrowing', () {
    test('offers only where the aux can move AND the supporter can reach, not every aux move', () {
      // A (supporter, mine) borders B and D. B (the aux) borders A, C and D.
      // Naively offering every province B could move to would include A and
      // C; the correct set is just D, the only one of B's own moves that A
      // also reaches.
      final map = {
        'A': _land('A', ['B', 'D']),
        'B': _land('B', ['A', 'C', 'D']),
        'C': _land('C', ['B']),
        'D': _land('D', ['A', 'B']),
      };
      final bloc = OrderBloc('g1');
      bloc.setMapData(map);
      bloc.setGameState(_gameState(
        phaseKind: kPhaseMovement,
        units: [
          _unit(province: 'A', isMine: true),
          _unit(province: 'B'),
        ],
      ));

      bloc.selectProvince('A');
      expect(bloc.currentState, OrderState.unitSelected);

      bloc.setAction(ActionType.support);
      expect(bloc.currentState, OrderState.supportAux);
      expect(bloc.validTargetProvinces, contains('B')); // support-hold candidate

      bloc.selectProvince('B');
      expect(bloc.currentState, OrderState.supportTarget);
      expect(bloc.auxProvince, 'B');
      expect(bloc.validTargetProvinces, {'D'});
    });
  });

  group('retreat occupied filter', () {
    test('excludes a province a non-dislodged unit already sits on, and rejects a tap on it', () {
      // R (dislodged, mine) borders X and Y. X is occupied by a
      // non-dislodged unit and must be filtered out; Y is empty.
      final map = {
        'R': _land('R', ['X', 'Y']),
        'X': _land('X', ['R']),
        'Y': _land('Y', ['R']),
      };
      final bloc = OrderBloc('g1');
      bloc.setMapData(map);
      bloc.setGameState(_gameState(
        phaseKind: kPhaseRetreat,
        units: [
          _unit(province: 'R', isMine: true, isDislodged: true),
          _unit(province: 'X'),
        ],
      ));

      bloc.selectProvince('R');
      expect(bloc.currentState, OrderState.unitSelected);

      bloc.setAction(ActionType.retreat);
      expect(bloc.currentState, OrderState.retreatTarget);
      expect(bloc.validTargetProvinces, {'Y'});

      // A tap on the occupied province is not a legal retreat target — it
      // must be silently rejected, not treated as a destination.
      bloc.selectProvince('X');
      expect(bloc.currentState, OrderState.retreatTarget);
      expect(bloc.targetProvince, isNull);
    });
  });

  group('pending-cancel dispatch does not swallow the next tap', () {
    test('retreat: re-tapping a different dislodged unit opens its own menu', () {
      final bloc = OrderBloc('g1');
      bloc.setGameState(_gameState(
        phaseKind: kPhaseRetreat,
        units: [
          _unit(province: 'R', isMine: true, isDislodged: true),
          _unit(province: 'S', isMine: true, isDislodged: true),
        ],
        myOrders: [_order(source: 'R', orderType: kOrderRetreat, target: 'Y', id: 7)],
      ));

      bloc.selectProvince('R');
      expect(bloc.currentState, OrderState.pendingCancel);
      expect(bloc.pendingOrder?['id'], 7);

      // Before the fix, every further tap was inert while `currentState`
      // stayed one of unitSelected/buildChoice/pendingCancel — only a ✕ tap
      // (bloc.reset()) could get out. S has no pending order of its own, so
      // this must open its own Retreat/Disband menu instead of staying put.
      bloc.selectProvince('S');
      expect(bloc.currentState, OrderState.unitSelected);
      expect(bloc.selectedProvince, 'S');
    });

    test('adjustment: re-tapping a different empty supply centre reopens the build menu there', () {
      final bloc = OrderBloc('g1');
      bloc.setGameState(_gameState(
        phaseKind: kPhaseAdjustment,
        units: const [],
        quota: 2,
        scOwnership: [
          {'province_code': 'E1', 'is_supply_center': true, 'empire_code': 'ME', 'is_port': false},
          {'province_code': 'E2', 'is_supply_center': true, 'empire_code': 'ME', 'is_port': true},
        ],
      ));

      bloc.selectProvince('E1');
      expect(bloc.currentState, OrderState.buildChoice);
      expect(bloc.selectedProvince, 'E1');

      bloc.selectProvince('E2');
      expect(bloc.currentState, OrderState.buildChoice);
      expect(bloc.selectedProvince, 'E2');
      expect(bloc.selectedScIsPort, isTrue);
    });
  });

  group('coastOptionsFor', () {
    test('a move filters to the coast(s) reachable from the source; a build keeps every option', () {
      // T is a split-coast province: its NC list names P1, its SC list
      // names P2 — the STP/BAR shape from the judge's finding, where a
      // fleet at BAR (== P1) must never be offered STP/SC.
      final map = {
        'T': _land('T', ['P1', 'P2'], extraAdj: {
          'data-adj-nc': ['P1'],
          'data-adj-sc': ['P2'],
        }),
        'P1': _land('P1', ['T']),
        'P2': _land('P2', ['T']),
      };
      final bloc = OrderBloc('g1');
      bloc.setMapData(map);
      bloc.setGameState(_gameState(phaseKind: kPhaseMovement, units: const []));

      expect(bloc.coastOptionsFor('T', from: 'P1'), ['NC']);
      expect(bloc.coastOptionsFor('T', from: 'P2'), ['SC']);
      // No source at all (a build): every coast stays on offer, unfiltered.
      expect(bloc.coastOptionsFor('T'), unorderedEquals(['NC', 'SC']));
    });
  });

  group('phase-change reset', () {
    test('a new phase id clears a stale selection instead of leaving it half-built', () {
      final bloc = OrderBloc('g1');
      bloc.setGameState(_gameState(phaseKind: kPhaseMovement, units: [
        _unit(province: 'A', isMine: true),
      ], phaseId: 1));
      bloc.selectProvince('A');
      expect(bloc.currentState, OrderState.unitSelected);

      // The server resolved movement into retreat while this selection sat
      // open (e.g. a ready-toggle or drawer refresh landed after
      // resolution) — the next game-state refresh must not leave A's stale
      // movement-phase selection behind for a phase that no longer has a
      // unit at A at all.
      bloc.setGameState(_gameState(phaseKind: kPhaseRetreat, units: const [], phaseId: 2));
      expect(bloc.currentState, OrderState.idle);
      expect(bloc.selectedProvince, isNull);
    });

    test('re-supplying the same phase id does not disturb an in-progress selection', () {
      final bloc = OrderBloc('g1');
      bloc.setGameState(_gameState(phaseKind: kPhaseMovement, units: [
        _unit(province: 'A', isMine: true),
      ], phaseId: 1));
      bloc.selectProvince('A');
      expect(bloc.currentState, OrderState.unitSelected);

      // Both Consumer<OrderBloc> builders in game_screen.dart call
      // setGameState with the *same* state on every build — idempotent
      // within one phase is what makes that safe.
      bloc.setGameState(_gameState(phaseKind: kPhaseMovement, units: [
        _unit(province: 'A', isMine: true),
      ], phaseId: 1));
      expect(bloc.currentState, OrderState.unitSelected);
      expect(bloc.selectedProvince, 'A');
    });
  });
}
