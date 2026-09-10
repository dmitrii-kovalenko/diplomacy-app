// Unit tests for reachability.dart — the direct port of orders_ui.js's
// reachability section (T18). These are pure functions over parsed map data
// plus a unit list, so unlike map_render_harness_test.dart (a "look at the
// PNG" harness) they get real assertions: every case below is picked from
// the real shipped SVGs so a wrong port shows up as a wrong province set,
// not just an eyeballed screenshot.
//
// Cases, and why each is here:
//  - PAR (inland): an army's target set is exactly its landlocked
//    adjacencies — the plainest "not sea" rule.
//  - GAS -> MAR (both coastal, adjacent, no shared sea and no river): the
//    actual Diplomacy rule a fleet cannot walk the coast on dry land for —
//    this is the case the old `adjData.type == 'coast'` approximation in
//    order_bloc.dart got wrong by construction (it never checked for a
//    shared sea at all).
//  - LON -> BRE via a fleet at ENG: a convoy destination not directly
//    adjacent to the army's own province, only reachable through the
//    fleet-occupied sea — proves the BFS chain, not just one-hop adjacency.
//  - STP/NC: a split-coast province's fleet edges must come from its own
//    coast's list (BAR/NWY), never the sibling SC coast's (BOT/FIN/LVN).
//  - BAL (archipelago, ancient_med.svg): a fleet at an adjacent sea must be
//    able to reach it — `isPortProv` has to accept archipelago, not just
//    coast, or this never lights up.
import 'dart:io';
import 'dart:ui' show Path;

import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

import 'package:diplomacy_app/blocs/game/order_bloc.dart';
import 'package:diplomacy_app/blocs/game/reachability.dart';
import 'package:diplomacy_app/widgets/map_viewer.dart';

/// The map SVGs live in the Django repo — see map_render_harness_test.dart
/// for why this is a sibling checkout rather than a bundled asset.
const _mapsDir = '/Users/dmitrii/Coding/Conspa/DjangoProject/assets/maps';

/// A minimal stand-in for `MapViewer._parseSvg`'s province loop: same
/// `data-type`/`data-adj*` reading, but skipping path geometry entirely
/// (`Reachability` never looks at `ProvinceData.path`) so these tests don't
/// need to round-trip an SVG path parser.
Map<String, ProvinceData> _parseProvinces(String svg) {
  final document = XmlDocument.parse(svg);
  final gProvinces = document.findAllElements('g').where((e) => e.getAttribute('id') == 'provinces').firstOrNull;
  final pathElements = gProvinces != null ? gProvinces.findAllElements('path') : document.findAllElements('path');
  final result = <String, ProvinceData>{};
  for (final element in pathElements) {
    final id = element.getAttribute('id');
    if (id == null) continue;
    final type = element.getAttribute('data-type') ?? 'land';
    final cssClass = element.getAttribute('class') ?? 'land';
    final adjStr = element.getAttribute('data-adj') ?? '';
    final adjacencies = adjStr.isNotEmpty ? adjStr.split(' ') : <String>[];
    final adjAttrs = <String, List<String>>{};
    for (final attribute in element.attributes) {
      final name = attribute.name.local;
      if (!name.startsWith('data-adj')) continue;
      final value = attribute.value.trim();
      adjAttrs[name] = value.isNotEmpty ? value.split(RegExp(r'\s+')) : const [];
    }
    result[id] = ProvinceData(
      id: id,
      type: type,
      adjacencies: adjacencies,
      path: Path(),
      cssClass: cssClass,
      adjAttrs: adjAttrs,
    );
  }
  return result;
}

Map<String, dynamic> _unit({
  required String province,
  required int unitType,
  bool isDislodged = false,
  bool isMine = false,
  String coast = '',
}) {
  return {
    'province_code': province,
    'unit_type': unitType,
    'is_dislodged': isDislodged,
    'is_mine': isMine,
    'coast': coast,
  };
}

void main() {
  final mapsDirExists = Directory(_mapsDir).existsSync();
  if (!mapsDirExists) {
    test('reachability against the real SVGs', () {
      markTestSkipped('Conspa checkout not found at $_mapsDir — these tests read '
          'the map SVGs from the Django repo, which is not available on this machine.');
    });
    return;
  }

  final classicSvg = File('$_mapsDir/diplomacy_classic.svg').readAsStringSync();
  final classicMap = _parseProvinces(classicSvg);
  final ancientMedSvg = File('$_mapsDir/ancient_med.svg').readAsStringSync();
  final ancientMedMap = _parseProvinces(ancientMedSvg);

  group('directTargets — army (diplomacy_classic)', () {
    test('an army in a landlocked province reaches exactly its non-sea neighbours', () {
      // PAR (inland) borders BRE/BUR/GAS/PIC, none of which are sea — the
      // whole adjacency list should come back untouched.
      final reach = Reachability(mapData: classicMap, units: [
        _unit(province: 'PAR', unitType: kUnitArmy, isMine: true),
      ]);
      final targets = reach.directTargets(_unit(province: 'PAR', unitType: kUnitArmy));
      expect(targets, {'BRE', 'BUR', 'GAS', 'PIC'});
    });
  });

  group('directTargets — fleet (diplomacy_classic)', () {
    test('rejects a coast-to-coast move with no shared sea or river (GAS -> MAR)', () {
      // GAS and MAR are adjacent coastal provinces, but a fleet cannot walk
      // the coast between them — the real Diplomacy rule this file exists
      // to encode. GAS's own adjacency doesn't include MAR's sea (GOL), so
      // the shared-sea fallback must fail too.
      final reach = Reachability(mapData: classicMap, units: []);
      final targets = reach.directTargets(_unit(province: 'GAS', unitType: kUnitFleet));
      expect(targets, isNot(contains('MAR')));
    });

    test('a split-coast fleet at STP/NC only gets its own coast\'s edges', () {
      final reach = Reachability(mapData: classicMap, units: []);
      final targets = reach.directTargets(_unit(province: 'STP', unitType: kUnitFleet, coast: 'NC'));
      expect(targets, {'BAR', 'NWY'});
      expect(targets, isNot(contains('BOT')));
      expect(targets, isNot(contains('FIN')));
      expect(targets, isNot(contains('LVN')));
    });

    test('coast_adjacency from the API overrides the SVG\'s data-adj-<coast> attributes', () {
      // Mirrors orders_ui.js's coastAdj precedence: an admin-edited DB row
      // must win over the SVG's own baked-in data-adj-nc, not merely
      // supplement it. BOT is a sea, so it passes the "fleets never go
      // inland" filter regardless of which coast list names it — it is
      // normally only on STP/SC's list (see the SVG's data-adj-sc), never
      // NC's, so its appearance here can only come from the override.
      final reach = Reachability(
        mapData: classicMap,
        units: [],
        coastAdjacency: {
          'STP': {
            'NC': ['BOT'],
          },
        },
      );
      final targets = reach.directTargets(_unit(province: 'STP', unitType: kUnitFleet, coast: 'NC'));
      expect(targets, {'BOT'});
      expect(targets, isNot(contains('BAR')));
      expect(targets, isNot(contains('NWY')));
    });
  });

  group('convoy (diplomacy_classic)', () {
    test('moveTargets offers a convoy destination only when a fleet sits in the chain', () {
      // LON is not directly adjacent to BRE, only through the sea province
      // ENG. With no fleet at sea, BRE must not appear; with one at ENG, it
      // must — plus WAL/YOR/BEL/PIC, and the direct WAL/YOR edges stay too.
      final army = _unit(province: 'LON', unitType: kUnitArmy, isMine: true);

      final withoutFleet = Reachability(mapData: classicMap, units: [army]);
      final withoutFleetTargets = withoutFleet.moveTargets(army);
      expect(withoutFleetTargets, {'WAL', 'YOR'});
      expect(withoutFleetTargets, isNot(contains('BRE')));

      final withFleet = Reachability(mapData: classicMap, units: [
        army,
        _unit(province: 'ENG', unitType: kUnitFleet),
      ]);
      final withFleetTargets = withFleet.moveTargets(army);
      expect(withFleetTargets, containsAll(['WAL', 'YOR', 'BEL', 'BRE', 'PIC']));
    });

    test('convoyableArmiesVia lists the coastal armies a fleet\'s chain reaches', () {
      final reach = Reachability(mapData: classicMap, units: [
        _unit(province: 'ENG', unitType: kUnitFleet, isMine: true),
        _unit(province: 'LON', unitType: kUnitArmy),
        _unit(province: 'MOS', unitType: kUnitArmy), // unrelated, must not appear
      ]);
      expect(reach.convoyableArmiesVia('ENG'), ['LON']);
    });
  });

  group('supportableUnits (diplomacy_classic)', () {
    test('includes a directly-reachable unit (support-hold) and one reachable via its own move (support-move)', () {
      final supporter = _unit(province: 'PAR', unitType: kUnitArmy, isMine: true);
      final reach = Reachability(mapData: classicMap, units: [
        supporter,
        _unit(province: 'BUR', unitType: kUnitArmy), // adjacent to PAR: support-hold
        _unit(province: 'MAR', unitType: kUnitArmy), // not adjacent to PAR, but MAR can move to GAS, which PAR reaches
        _unit(province: 'MOS', unitType: kUnitArmy), // unrelated, must not appear
      ]);
      final supportable = reach.supportableUnits(supporter);
      expect(supportable, containsAll(['BUR', 'MAR']));
      expect(supportable, isNot(contains('MOS')));
      expect(supportable, isNot(contains('PAR'))); // never supports itself
    });
  });

  group('archipelago (ancient_med)', () {
    test('isPortProv accepts archipelago, so a fleet in an adjacent sea can reach it', () {
      // BAL (Balearic Islands) is data-type="archipelago", not "coast" — the
      // pre-T18 order_bloc.dart approximation only checked for "coast" and
      // would have silently dropped this target.
      expect(ancientMedMap['BAL']?.type, 'archipelago');
      final reach = Reachability(mapData: ancientMedMap, units: []);
      final targets = reach.directTargets(_unit(province: 'BER', unitType: kUnitFleet));
      expect(targets, contains('BAL'));
    });
  });

  group('occupiedProvinces', () {
    test('collects only non-dislodged units\' provinces', () {
      final occupied = occupiedProvinces([
        _unit(province: 'PAR', unitType: kUnitArmy),
        _unit(province: 'BUR', unitType: kUnitArmy, isDislodged: true),
      ]);
      expect(occupied, {'PAR'});
    });
  });
}
