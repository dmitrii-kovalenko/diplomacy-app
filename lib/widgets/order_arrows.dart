import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';

import '../blocs/game/order_bloc.dart'
    show kOrderConvoy, kOrderHold, kOrderMove, kOrderRetreat, kOrderSupport;
import 'arrow_geometry.dart' as geo;

/// One order to draw on the board, already resolved to map-space points.
///
/// `game_screen.dart` is where a province code turns into an [Offset] (unit
/// centre → label position → province-bounds fallback, mirroring the Mini
/// App's `pt()`), and where the aggregation that spans *multiple* orders
/// lives too: which routes already have a move order (`hasMoveFor` in
/// `arrows_overlay.js`), which fleets convoy which route, and whether a
/// supported move is provably missing (`supportedMoveMissing`). All of that
/// needs the raw province codes my_orders carries; this class only carries
/// the outcome of it for one order, in the coordinate space
/// [OrderArrowsPainter] paints in.
class Order {
  /// One of `kOrderHold` / `kOrderMove` / `kOrderSupport` / `kOrderConvoy` /
  /// `kOrderRetreat` from `lib/blocs/game/order_bloc.dart`. A retreat draws
  /// exactly like a move — `OrderArrowsPainter` dispatches both to the same
  /// glyph, matching `arrows_overlay.js`'s `order_type === 4` case, which
  /// also just calls `movePath(src, dst)`. Build/disband orders have no
  /// arrow of their own; `OrderArrowsPainter` silently skips any other value.
  final int orderType;

  /// The ordering unit's own position — always present.
  final Offset source;

  /// The move/support/convoy destination. Null for a hold or a
  /// support-to-hold.
  final Offset? target;

  /// The supported or convoyed unit's position (Support and Convoy orders
  /// only).
  final Offset? aux;

  /// Positions of every fleet convoying the route this order refers to
  /// (source→target for a Move, aux→target for a Support-of-attack).
  /// Submission order, not route order — [OrderArrowsPainter] chains them
  /// nearest-first itself so a multi-fleet arc never zigzags.
  final List<Offset> convoyFleets;

  final Color color;

  /// The order's resolution once the phase has adjudicated it (`0` =
  /// succeeded, 1-4 = a failure kind — see `ORDER_RESULT_*` in
  /// `game/choices.py`). Always null for a live, unresolved order, and null
  /// too for a history row the adjudicator never scored. For the failure
  /// halo, null counts as not-failed, the same as `0` (see
  /// [OrderArrowsPainter._isFailed]). Convoy dashing differs: an arc is solid
  /// only when this is exactly `0`, so a null result draws dashed — read
  /// regardless of `history`, matching the Mini App's `convoyDashFor`.
  final int? result;

  /// Set for a support-of-attack whose supported move cannot be found among
  /// the orders in view — i.e. drawing a confident "ghost" arrow would
  /// assert a move nobody made. In history mode every order of the phase is
  /// in view, so this is provable for anyone's support; live it's provable
  /// only for the player's own units, since a foreign unit's orders stay
  /// secret until resolution — `game_screen.dart` computes this the same way
  /// `arrows_overlay.js`'s `supportedMoveMissing` does. Drawn with the same
  /// red halo as a failed order (`OrderArrowsPainter._failed`), live or in
  /// history, since it is one, just for a reason the server never got to
  /// report.
  final bool orphanedSupport;

  const Order({
    required this.orderType,
    required this.source,
    this.target,
    this.aux,
    this.convoyFleets = const [],
    required this.color,
    this.result,
    this.orphanedSupport = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Order &&
          runtimeType == other.runtimeType &&
          orderType == other.orderType &&
          source == other.source &&
          target == other.target &&
          aux == other.aux &&
          listEquals(convoyFleets, other.convoyFleets) &&
          color == other.color &&
          result == other.result &&
          orphanedSupport == other.orphanedSupport;

  @override
  int get hashCode => Object.hash(
        orderType,
        source,
        target,
        aux,
        Object.hashAll(convoyFleets),
        color,
        result,
        orphanedSupport,
      );
}

// ── Styling constants, mirroring the widths/dashes/opacities
// `arrows_overlay.js` draws with (the geometry itself carries none of this —
// see arrow_geometry.dart's file doc). ──────────────────────────────────────
const double _moveArrowWidth = 3.75;
const double _convoyArrowWidth = 3.0;
const double _supportLineWidth = 3.0;
const double _supportedGhostWidth = 2.25;
const double _markerStrokeWidth = 2.25;
const double _holdStrokeWidth = 3.0;
const double _holdRadius = 16.0;

const List<double> _supportLineDash = [4, 3];
const List<double> _holdDash = [2, 2];
const List<double> _convoyDash = [6, 5];
const List<double> _orphanedGhostDash = [1, 5];

// Live-mode ghost opacity. History drops to 0.4 (see
// `OrderArrowsPainter._ghostOpacityFor`) — arrows_overlay.js dims the
// supported-move ghost further once a phase has resolved, on top of the
// general `baseOpacity` drop every other stroke already gets.
const double _ghostOpacity = 0.55;
const double _ghostOpacityHistory = 0.4;
const double _orphanedGhostOpacity = 0.3;

/// The failure outline. Deliberately not `AppColors.of(context).red`
/// (`#FF453A`, the design system's destructive/state red): `arrows_overlay.js`
/// paints this exact, slightly lighter red (`#ff6b6b`) for the halo, distinct
/// from every other red in the app, because it sits on top of an already
/// colourful, busy map rather than flat UI chrome — reusing the UI's red
/// would either fight an empire colour that happens to be red-ish or read as
/// too dark against the board art. This is cartography-adjacent overlay ink,
/// like `_neutralStyles`/the label styles in `map_viewer.dart`, not a design
/// token.
const Color _failOutlineColor = Color(0xFFFF6B6B);

/// Extra stroke width the failure halo adds under an arrow's own line
/// (`strokeArrow`'s `width + 3` in `arrows_overlay.js`).
const double _failOutlineExtraWidth = 3.0;

/// Stroke width of the failure halo drawn under a marker (the attack-support
/// circle or hold-support square) — a fixed 5, not `width + 3`: the JS hard-
/// codes this one (`arrows_overlay.js:297,320`) instead of deriving it from
/// the marker's own 2.25 stroke.
const double _markerFailOutlineWidth = 5.0;

class OrderArrowsPainter extends CustomPainter {
  final List<Order> orders;

  /// True once [orders] came from a resolved history phase rather than the
  /// live board. It gates the failure halo only: a live order is never
  /// resolved, so `_isFailed` stays false live even if a stale `result`
  /// arrived. Convoy dashing reads [Order.result] either way (see
  /// `_convoyDashFor`). It also switches every stroke's opacity to 0.85,
  /// matching `arrows_overlay.js`'s `baseOpacity`.
  final bool history;

  OrderArrowsPainter(this.orders, {this.history = false});

  @override
  void paint(Canvas canvas, Size size) {
    // One broken order must never blank the whole overlay — mirrors the
    // try/catch arrows_overlay.js wraps around each call to `renderOrder`
    // (an uncaught error in one order's geometry used to bubble up and take
    // the rest of the board's arrows down with it).
    for (final order in orders) {
      try {
        _renderOrder(canvas, order);
      } catch (e, st) {
        debugPrint('order arrow render failed: $e\n$st');
      }
    }
  }

  double get _baseOpacity => history ? 0.85 : 1.0;

  double _ghostOpacityFor() => history ? _ghostOpacityHistory : _ghostOpacity;

  /// A resolved order that didn't take effect gets the red outline —
  /// history only, since a live order isn't resolved yet. `result == null`
  /// (the resolver never scored it) and `result == 0` (it succeeded) both
  /// read as "not failed", matching `arrows_overlay.js`'s
  /// `!!(history && o.result && o.result !== 0)` — treating a falsy
  /// `result` (`null` or `0`) as "not failed" the same way `!!o.result`
  /// does in JS.
  bool _isFailed(Order order) =>
      history && order.result != null && order.result != 0;

  /// The red-halo test actually used everywhere an order draws its main
  /// line/marker: failed (history) or an orphaned support (live or
  /// history) — see [Order.orphanedSupport]'s doc for why the latter isn't
  /// gated on `history`. Always equal to [_isFailed] for a non-support
  /// order, since [Order.orphanedSupport] defaults to false for those.
  bool _failed(Order order) => _isFailed(order) || order.orphanedSupport;

  void _renderOrder(Canvas canvas, Order order) {
    switch (order.orderType) {
      case kOrderHold:
        _drawHold(canvas, order);
        return;
      case kOrderMove:
      case kOrderRetreat:
        _drawMove(canvas, order);
        return;
      case kOrderSupport:
        _drawSupport(canvas, order);
        return;
      case kOrderConvoy:
        _drawConvoy(canvas, order);
        return;
      default:
        // Build/disband orders have no arrow of their own.
        return;
    }
  }

  void _drawHold(Canvas canvas, Order order) {
    final ring = Path()..addOval(Rect.fromCircle(center: order.source, radius: _holdRadius));
    _strokeArrow(canvas, ring, order.color, _holdStrokeWidth,
        dash: _holdDash, failed: _isFailed(order));
  }

  void _drawMove(Canvas canvas, Order order) {
    final target = order.target;
    if (target == null) return;
    final failed = _failed(order);
    if (order.convoyFleets.isNotEmpty) {
      // Convoyed move: one arc through every convoying fleet, nearest-first,
      // never a straight line across the sea and never a second arrow drawn
      // on top of it.
      final chain = _chainThrough(order.source, order.convoyFleets, target);
      final path = geo.convoyedPath(chain);
      _strokeArrow(canvas, path, order.color, _moveArrowWidth,
          dash: _convoyDashFor(order), failed: failed);
      return;
    }
    final path = geo.movePath(order.source, target);
    _strokeArrow(canvas, path, order.color, _moveArrowWidth, failed: failed);
  }

  void _drawSupport(Canvas canvas, Order order) {
    final aux = order.aux;
    if (aux == null) return;
    final target = order.target;
    final failed = _failed(order);

    if (target == null || target == aux) {
      // Support of a hold: supporter, defended unit.
      final glyph = geo.defenseSupportPath(order.source, aux);
      _strokeArrow(canvas, glyph.line, order.color, _supportLineWidth,
          dash: _supportLineDash, failed: failed);
      _drawMarker(canvas, glyph.square, order.color, failed: failed);
      return;
    }

    // Support of an attack: supporter, attackFrom (aux), attackTo (target).
    // When the supported route is itself convoyed, the ghost has to follow
    // the fleet chain's arc instead of a plain curve, or it would be aimed
    // straight through open sea.
    final geo.AttackSupportGlyph glyph = order.convoyFleets.isNotEmpty
        ? geo.attackSupportConvoyedPath(order.source, _chainThrough(aux, order.convoyFleets, target))
        : geo.attackSupportPath(order.source, aux, target);

    _drawSupportedGhost(canvas, glyph.supported, order);
    _strokeArrow(canvas, glyph.line, order.color, _supportLineWidth,
        dash: _supportLineDash, failed: failed);
    _drawMarker(canvas, glyph.circle, order.color, failed: failed);
  }

  void _drawSupportedGhost(Canvas canvas, Path supported, Order order) {
    // The ghost never wears the failure halo, in history or live — it's an
    // aside about what's being supported, not the order itself
    // (arrows_overlay.js never passes `failed` into this piece).
    if (order.orphanedSupport) {
      // Not a move anybody ordered — draw it as a dotted intention, never as
      // something that looks like it is going to happen.
      _strokeArrow(
        canvas,
        supported,
        order.color,
        _supportedGhostWidth,
        dash: _orphanedGhostDash,
        opacity: _orphanedGhostOpacity,
        cap: StrokeCap.round,
      );
    } else {
      _strokeArrow(canvas, supported, order.color, _supportedGhostWidth,
          opacity: _ghostOpacityFor());
    }
  }

  void _drawConvoy(Canvas canvas, Order order) {
    // Reaching this case at all means the convoyed army's own MOVE order was
    // not in this order set (game_screen.dart already skips a convoy order
    // whose move it can see) — draw the through-ships arc directly: army →
    // fleet → destination, single arrowhead at the end.
    final aux = order.aux;
    final target = order.target;
    if (aux == null || target == null) return;
    final path = geo.convoyedPath([aux, order.source, target]);
    _strokeArrow(canvas, path, order.color, _convoyArrowWidth,
        dash: _convoyDashFor(order), failed: _isFailed(order));
  }

  void _drawMarker(Canvas canvas, Path marker, Color color, {bool failed = false}) {
    if (failed) {
      // Stroke-only red copy underneath: a 5px stroke under the marker's own
      // 2.25px one, so about 1.4px of red shows on each side and it reads as
      // a ring around the marker rather than a blob behind it
      // (arrows_overlay.js's `stroke-width: 5`, `fill: none`).
      canvas.drawPath(
        marker,
        Paint()
          ..color = _failOutlineColor.withOpacity(_baseOpacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = _markerFailOutlineWidth,
      );
    }
    // The marker's own fill stays fully opaque even in history — the JS sets
    // `stroke-opacity` on the coloured circle/square but never touches its
    // `fill`, so only the outline dims with the rest of the overlay.
    canvas.drawPath(marker, Paint()..color = color..style = PaintingStyle.fill);
    canvas.drawPath(
      marker,
      Paint()
        ..color = color.withOpacity(_baseOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _markerStrokeWidth,
    );
  }

  /// Strokes `path` in `color`. When `failed`, first lays the same path
  /// underneath in [_failOutlineColor] at `width + 3` so the failure reads as
  /// an outline around the arrow rather than a recolour of it — ports
  /// `arrows_overlay.js`'s `strokeArrow` exactly, underneath path included.
  void _strokeArrow(
    Canvas canvas,
    Path path,
    Color color,
    double width, {
    List<double>? dash,
    double? opacity,
    StrokeCap cap = StrokeCap.butt,
    bool failed = false,
  }) {
    final resolvedOpacity = opacity ?? _baseOpacity;
    final drawn = dash == null ? path : dashPath(path, dashArray: CircularIntervalList<double>(dash));
    if (failed) {
      canvas.drawPath(
        drawn,
        Paint()
          ..color = _failOutlineColor.withOpacity(resolvedOpacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = width + _failOutlineExtraWidth
          ..strokeCap = cap,
      );
    }
    canvas.drawPath(
      drawn,
      Paint()
        ..color = color.withOpacity(resolvedOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = cap,
    );
  }

  @override
  bool shouldRepaint(covariant OrderArrowsPainter oldDelegate) {
    return oldDelegate.history != history || !listEquals(oldDelegate.orders, orders);
  }
}

/// Dash pattern for a convoy / convoyed-move arc: solid once it has resolved
/// successfully (`result == 0`), dashed while it's still failed or pending —
/// which, for a live unresolved order, is always (there is no `result` yet).
List<double>? _convoyDashFor(Order order) => order.result == 0 ? null : _convoyDash;

/// Convoy orders arrive in submission order, not route order. Walk the
/// fleets nearest-first from the army so a 2+ fleet arc doesn't zigzag.
List<Offset> _chainThrough(Offset start, List<Offset> fleets, Offset end) {
  final rest = List<Offset>.from(fleets);
  final out = <Offset>[start];
  var cur = start;
  while (rest.isNotEmpty) {
    var bestI = 0;
    var bestD = double.infinity;
    for (var i = 0; i < rest.length; i++) {
      final dx = rest[i].dx - cur.dx;
      final dy = rest[i].dy - cur.dy;
      final d = dx * dx + dy * dy;
      if (d < bestD) {
        bestD = d;
        bestI = i;
      }
    }
    cur = rest.removeAt(bestI);
    out.add(cur);
  }
  out.add(end);
  return out;
}
