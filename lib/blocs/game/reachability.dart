// Reachability — mirrors the server's validation.py.
//
// A direct port of DjangoProject/assets/game/orders_ui.js's own "Reachability"
// section (lines 214-341 as of this port). Everything below answers one
// question: which provinces is it LEGAL to tap for the current half-built
// order? Only those stay lit (the rest of the map is dimmed) and only those
// accept taps — impossible orders (army into the sea, fleet convoying a
// fleet, "convoy" with no fleet chain…) never even render.
//
// CONTEXT.md's two-source rule is the reason this file exists at all: a move
// is legal only when both the SVG's own `data-adj` (read here, via
// [ProvinceData]) and the DB `ProvinceAdjacency` table (validated server-side
// in validation.py) allow it. This class mirrors the SVG half only — the
// server keeps the last word, and a target this class offers that the server
// still rejects means the two sources have drifted (a re-import or a data
// migration fixes that; loosening this file does not).
import '../../widgets/map_viewer.dart';
import 'order_bloc.dart' show kUnitArmy, kUnitFleet;

/// Split-coast labels (lowercase, matching the SVG's `data-adj-<coast>`
/// attributes). Keep in sync with `COAST_CODES` in orders_ui.js and
/// `COAST_CODES` in choices.py — adding a coast there only takes effect here
/// once it's added to this list too.
const List<String> kCoastCodes = ['nc', 'sc', 'ec', 'wc'];

/// One unit row off the game-state payload (`game/api/serializers.py`'s
/// `units` list): `province_code`, `unit_type` (0 army / 1 fleet), `coast`,
/// `is_dislodged`, `is_mine`, `empire_code`. Kept as a raw `Map`, matching
/// every other reader of this payload in this codebase (`board_state.dart`,
/// the old `order_bloc.dart`) rather than introducing a model type nothing
/// else uses.
typedef UnitRow = Map<String, dynamic>;

/// Provinces currently occupied by any non-dislodged unit — a retreat may
/// not land on one of these. Ported from the `occupied` set built inline in
/// `orders_ui.js`'s `onProvinceClick` retreat branch. The server additionally
/// rejects the attacker's origin and any standoff province from last phase;
/// those aren't derivable client-side (the client doesn't know who attacked
/// from where), so this filter is deliberately incomplete and the server
/// keeps the last word on both.
Set<String> occupiedProvinces(List<dynamic> units) {
  final out = <String>{};
  for (final raw in units) {
    final u = raw as UnitRow;
    if (u['is_dislodged'] != true) {
      final code = u['province_code'] as String?;
      if (code != null) out.add(code);
    }
  }
  return out;
}

/// Reachability for one game snapshot: the parsed map ([ProvinceData], keyed
/// by province code) plus the live `units` list and the DB-derived coast
/// data. Construct one per game-state refresh — [fleetSeaSet] memoizes
/// itself the first time it's asked for, which matters on `known_world_901`
/// (269 provinces, 52 seas): [convoySeasFrom] runs a BFS per selection, and
/// re-deriving the occupied-seas set for every one of those would be a BFS's
/// worth of wasted work on every single tap.
class Reachability {
  Reachability({
    required this.mapData,
    required this.units,
    Map<String, dynamic>? coastAdjacency,
    List<dynamic>? splitCoastProvinces,
  })  : _coastAdjacency = _normalizeCoastAdjacency(coastAdjacency),
        _splitCoastProvinces =
            (splitCoastProvinces ?? const []).map((e) => e.toString()).toSet();

  final Map<String, ProvinceData> mapData;
  final List<dynamic> units;
  final Map<String, Map<String, List<String>>> _coastAdjacency;
  final Set<String> _splitCoastProvinces;

  Set<String>? _fleetSeaSetCache;

  static Map<String, Map<String, List<String>>> _normalizeCoastAdjacency(
    Map<String, dynamic>? raw,
  ) {
    if (raw == null) return const {};
    final out = <String, Map<String, List<String>>>{};
    raw.forEach((code, coasts) {
      final coastMap = <String, List<String>>{};
      (coasts as Map<String, dynamic>).forEach((coast, list) {
        coastMap[coast.toUpperCase()] =
            (list as List).map((e) => e.toString()).toList();
      });
      out[code] = coastMap;
    });
    return out;
  }

  String provTypeOf(String code) => mapData[code]?.type ?? 'land';

  bool isSeaProv(String code) => provTypeOf(code) == 'sea';

  // The SVG's data-type values are sea | inland | coast | archipelago (one
  // archipelago province ships today, in ancient_med.svg). isPortProv
  // accepts both coast and archipelago — a fleet can be built at, or land
  // on, either.
  bool isPortProv(String code) {
    final t = provTypeOf(code);
    return t == 'coast' || t == 'archipelago';
  }

  List<String> adjListOf(String code, [String attr = 'data-adj']) {
    return mapData[code]?.adjAttrs[attr] ?? const [];
  }

  UnitRow? unitAt(String code) {
    for (final raw in units) {
      final u = raw as UnitRow;
      if (u['province_code'] == code && u['is_dislodged'] != true) return u;
    }
    return null;
  }

  // Coast edges, sourced from the server's DB-derived coast_adjacency map (so
  // coasts configured in the admin drive the UI). Falls back to the SVG's
  // data-adj-<coast> attributes for legacy maps with no DB coast rows.
  List<String> coastEdges(String code, String coast) {
    final ca = _coastAdjacency[code];
    if (ca != null) return ca[coast.toUpperCase()] ?? const [];
    return adjListOf(code, 'data-adj-${coast.toLowerCase()}');
  }

  // Which coasts a province exposes (e.g. ["NC","SC","WC"]). Nothing
  // hardcoded per province — comes straight from the data.
  List<String> coastOptions(String code) {
    final ca = _coastAdjacency[code];
    if (ca != null) return ca.keys.toList();
    final data = mapData[code];
    if (data == null) return const [];
    return kCoastCodes
        .where((c) => (data.adjAttrs['data-adj-$c'] ?? const []).isNotEmpty)
        .map((c) => c.toUpperCase())
        .toList();
  }

  bool isSplitCoast(String code) =>
      coastOptions(code).isNotEmpty || _splitCoastProvinces.contains(code);

  // Single-step move targets for a unit. Armies use the coast-less edges and
  // never enter the sea. Fleets need a fleet-navigable edge: seas always;
  // coast<->coast only along a shared sea or a data-adj-river edge;
  // split-coast provinces only via the right per-coast list (own coast on
  // the way out, any coast that lists us on the way in).
  Set<String> directTargets(UnitRow unit) {
    final code = unit['province_code'] as String;
    final unitType = (unit['unit_type'] as num?)?.toInt() ?? kUnitArmy;
    if (unitType == kUnitArmy) {
      return adjListOf(code).where((n) => !isSeaProv(n)).toSet();
    }
    final coast = unit['coast'] as String?;
    final hasCoast = coast != null && coast.isNotEmpty;
    final out = hasCoast ? coastEdges(code, coast) : adjListOf(code);
    final fromSea = isSeaProv(code);
    final river = adjListOf(code, 'data-adj-river');
    final plain = adjListOf(code);
    return out.where((n) {
      if (isSplitCoast(n)) {
        return coastOptions(n).any((c) => coastEdges(n, c).contains(code));
      }
      if (isSeaProv(n)) return true;
      if (!isPortProv(n)) return false; // fleets never go inland
      if (hasCoast || fromSea) return true; // those lists are fleet edges already
      if (river.contains(n) || adjListOf(n, 'data-adj-river').contains(code)) {
        return true;
      }
      return adjListOf(n).any((s) => isSeaProv(s) && plain.contains(s));
    }).toSet();
  }

  // Sea provinces currently occupied by a fleet (any empire — foreign fleets
  // can convoy too). Convoy chains can only run through these.
  Set<String> fleetSeaSet() {
    final cached = _fleetSeaSetCache;
    if (cached != null) return cached;
    final seas = <String>{};
    for (final raw in units) {
      final u = raw as UnitRow;
      final unitType = (u['unit_type'] as num?)?.toInt();
      final code = u['province_code'] as String?;
      if (unitType == kUnitFleet &&
          u['is_dislodged'] != true &&
          code != null &&
          isSeaProv(code)) {
        seas.add(code);
      }
    }
    _fleetSeaSetCache = seas;
    return seas;
  }

  // All fleet-occupied seas a convoy chain starting at coastal `fromCode`
  // could run through (BFS across adjacent fleet-occupied seas).
  Set<String> convoySeasFrom(String fromCode, Set<String> seas) {
    final visited = <String>{};
    final queue = adjListOf(fromCode).where((n) => seas.contains(n)).toList();
    while (queue.isNotEmpty) {
      final sea = queue.removeLast();
      if (visited.contains(sea)) continue;
      visited.add(sea);
      for (final n in adjListOf(sea)) {
        if (seas.contains(n) && !visited.contains(n)) queue.add(n);
      }
    }
    return visited;
  }

  // Ports an army at `fromCode` can actually be convoyed to. Pass `viaSea`
  // to require the chain to run through that sea (the convoying fleet).
  Set<String> convoyTargets(String fromCode, [String? viaSea]) {
    final out = <String>{};
    final comp = convoySeasFrom(fromCode, fleetSeaSet());
    if (viaSea != null && !comp.contains(viaSea)) return out;
    for (final sea in comp) {
      for (final n in adjListOf(sea)) {
        if (n != fromCode && isPortProv(n)) out.add(n);
      }
    }
    return out;
  }

  // Every province the unit could legally be ordered to move to right now
  // (single step + feasible convoy moves for coastal armies).
  Set<String> moveTargets(UnitRow unit) {
    final out = directTargets(unit).toSet();
    final unitType = (unit['unit_type'] as num?)?.toInt() ?? kUnitArmy;
    final code = unit['province_code'] as String;
    if (unitType == kUnitArmy && isPortProv(code)) {
      out.addAll(convoyTargets(code));
    }
    return out;
  }

  // Coastal armies (own or foreign) that a chain through the fleet sitting
  // at sea `fleetCode` could pick up.
  List<String> convoyableArmiesVia(String fleetCode) {
    final seas = fleetSeaSet();
    final out = <String>[];
    for (final raw in units) {
      final u = raw as UnitRow;
      final unitType = (u['unit_type'] as num?)?.toInt();
      final code = u['province_code'] as String?;
      if (unitType != kUnitArmy || u['is_dislodged'] == true || code == null) {
        continue;
      }
      if (!isPortProv(code)) continue;
      if (convoySeasFrom(code, seas).contains(fleetCode)) out.add(code);
    }
    return out;
  }

  // Provinces holding a unit (own or foreign) this unit could support:
  // either we reach their province (support-hold), or we reach some
  // destination they can legally move to (support-move).
  List<String> supportableUnits(UnitRow unit) {
    final reach = directTargets(unit);
    final out = <String>[];
    final ownCode = unit['province_code'] as String?;
    for (final raw in units) {
      final u = raw as UnitRow;
      final code = u['province_code'] as String?;
      if (u['is_dislodged'] == true || code == null || code == ownCode) {
        continue;
      }
      if (reach.contains(code)) {
        out.add(code);
        continue;
      }
      var movable = false;
      for (final t in moveTargets(u)) {
        if (reach.contains(t)) {
          movable = true;
          break;
        }
      }
      if (movable) out.add(code);
    }
    return out;
  }
}
