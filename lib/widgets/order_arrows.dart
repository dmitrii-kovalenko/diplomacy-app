import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';

import '../blocs/game/order_bloc.dart' show kOrderConvoy, kOrderHold, kOrderMove, kOrderSupport;
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
  /// One of `kOrderHold` / `kOrderMove` / `kOrderSupport` / `kOrderConvoy`
  /// from `lib/blocs/game/order_bloc.dart`. Retreat/build/disband orders
  /// aren't modelled here yet (T17 and friends) — `OrderArrowsPainter`
  /// silently skips any other value.
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
  /// succeeded). Always null for a live, unresolved order. This client
  /// doesn't draw the failed-order red outline yet (T16), but a convoy or
  /// convoyed-move arc already dashes itself while pending using this field,
  /// matching the Mini App's `convoyDashFor`.
  final int? result;

  /// Set for a support-of-attack whose supported move cannot be found among
  /// the supporting player's own orders — i.e. drawing a confident "ghost"
  /// arrow would assert a move nobody made. Only provable for the player's
  /// own units (a foreign unit's orders stay secret until resolution), which
  /// is exactly what `my_orders` covers — `game_screen.dart` computes this
  /// the same way `arrows_overlay.js`'s `supportedMoveMissing` does.
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

// 0.4 in history mode, per arrows_overlay.js — moot here since T15 doesn't
// draw history arrows yet (T16).
const double _ghostOpacity = 0.55;
const double _orphanedGhostOpacity = 0.3;

class OrderArrowsPainter extends CustomPainter {
  final List<Order> orders;

  OrderArrowsPainter(this.orders);

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

  void _renderOrder(Canvas canvas, Order order) {
    switch (order.orderType) {
      case kOrderHold:
        _drawHold(canvas, order);
        return;
      case kOrderMove:
        _drawMove(canvas, order);
        return;
      case kOrderSupport:
        _drawSupport(canvas, order);
        return;
      case kOrderConvoy:
        _drawConvoy(canvas, order);
        return;
      default:
        // Retreat/build/disband arrows aren't modelled yet.
        return;
    }
  }

  void _drawHold(Canvas canvas, Order order) {
    final ring = Path()..addOval(Rect.fromCircle(center: order.source, radius: _holdRadius));
    _strokeArrow(canvas, ring, order.color, _holdStrokeWidth, dash: _holdDash);
  }

  void _drawMove(Canvas canvas, Order order) {
    final target = order.target;
    if (target == null) return;
    if (order.convoyFleets.isNotEmpty) {
      // Convoyed move: one arc through every convoying fleet, nearest-first,
      // never a straight line across the sea and never a second arrow drawn
      // on top of it.
      final chain = _chainThrough(order.source, order.convoyFleets, target);
      final path = geo.convoyedPath(chain);
      _strokeArrow(canvas, path, order.color, _moveArrowWidth, dash: _convoyDashFor(order));
      return;
    }
    final path = geo.movePath(order.source, target);
    _strokeArrow(canvas, path, order.color, _moveArrowWidth);
  }

  void _drawSupport(Canvas canvas, Order order) {
    final aux = order.aux;
    if (aux == null) return;
    final target = order.target;

    if (target == null || target == aux) {
      // Support of a hold: supporter, defended unit.
      final glyph = geo.defenseSupportPath(order.source, aux);
      _strokeArrow(canvas, glyph.line, order.color, _supportLineWidth, dash: _supportLineDash);
      _drawMarker(canvas, glyph.square, order.color);
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
    _strokeArrow(canvas, glyph.line, order.color, _supportLineWidth, dash: _supportLineDash);
    _drawMarker(canvas, glyph.circle, order.color);
  }

  void _drawSupportedGhost(Canvas canvas, Path supported, Order order) {
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
      _strokeArrow(canvas, supported, order.color, _supportedGhostWidth, opacity: _ghostOpacity);
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
    _strokeArrow(canvas, path, order.color, _convoyArrowWidth, dash: _convoyDashFor(order));
  }

  void _drawMarker(Canvas canvas, Path marker, Color color) {
    canvas.drawPath(marker, Paint()..color = color..style = PaintingStyle.fill);
    canvas.drawPath(
      marker,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = _markerStrokeWidth,
    );
  }

  void _strokeArrow(
    Canvas canvas,
    Path path,
    Color color,
    double width, {
    List<double>? dash,
    double opacity = 1,
    StrokeCap cap = StrokeCap.butt,
  }) {
    final drawn = dash == null ? path : dashPath(path, dashArray: CircularIntervalList<double>(dash));
    canvas.drawPath(
      drawn,
      Paint()
        ..color = color.withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = cap,
    );
  }

  @override
  bool shouldRepaint(covariant OrderArrowsPainter oldDelegate) {
    return !listEquals(oldDelegate.orders, orders);
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
