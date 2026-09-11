// Renders one of every in-scope order glyph through the real
// `OrderArrowsPainter` (via `MapViewer`) onto a synthetic board, and writes
// the result to `build/map_render/order_arrows.png` — arrow geometry is
// exactly the kind of thing that compiles, analyzes clean, and draws
// nonsense, so this exists to be looked at with the Read tool, the same way
// `map_render_harness_test.dart` looks at the base cartography.
//
// Run with `flutter test test/order_arrows_render_test.dart`, then read the
// PNG. The board itself is synthetic (a single blank province) rather than
// a real map SVG: every order's geometry only depends on the [Offset]s it
// carries, not on real cartography, so a big blank canvas with hand-picked
// coordinates makes each glyph easy to isolate and measure — a real map
// would just add 269 unrelated province paths between the reader and the
// thing being checked.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diplomacy_app/blocs/game/order_bloc.dart';
import 'package:diplomacy_app/widgets/map_viewer.dart';
import 'package:diplomacy_app/widgets/order_arrows.dart';

const _canvasSize = Size(1200, 700);

String _syntheticSvg() {
  final w = _canvasSize.width.toInt();
  final h = _canvasSize.height.toInt();
  return '''
<svg width="$w" height="$h" viewBox="0 0 $w $h">
  <g id="provinces">
    <path id="BOARD" class="land" data-type="inland" d="M0 0 H$w V$h H0 Z" />
  </g>
</svg>
''';
}

class _Caption {
  final String text;
  final Offset at;
  const _Caption(this.text, this.at);
}

void main() {
  testWidgets('renders one of each in-scope order glyph', (tester) async {
    tester.view.physicalSize = _canvasSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Brass, matching the design system's accent gold — arrows must never
    // hardcode a colour of their own (that was T15's whole colour bug), but
    // the test still has to pick *something* to pass in.
    const empireColor = Color(0xFFE3B457);

    final orders = <Order>[
      // Hold: dashed ring at the unit.
      const Order(
          orderType: kOrderHold, source: Offset(100, 100), color: empireColor),

      // Move: curved arrow with a two-line arrowhead.
      const Order(
          orderType: kOrderMove,
          source: Offset(300, 100),
          target: Offset(550, 100),
          color: empireColor),

      // Support-to-hold: dashed curve + square marker on the defended unit.
      const Order(
          orderType: kOrderSupport,
          source: Offset(750, 100),
          aux: Offset(950, 100),
          color: empireColor),

      // Support-of-attack: dashed line + circle marker + a faint ghost of
      // the move being supported.
      const Order(
        orderType: kOrderSupport,
        source: Offset(100, 300),
        aux: Offset(300, 300),
        target: Offset(550, 300),
        color: empireColor,
      ),

      // Convoyed move: one arc through 2 fleets, submitted out of route
      // order on purpose — `chainThrough` must still visit the nearer fleet
      // first (900,420) or the arc zigzags out to (1050,300) and back.
      const Order(
        orderType: kOrderMove,
        source: Offset(750, 300),
        target: Offset(1200, 300),
        convoyFleets: [Offset(1050, 300), Offset(900, 420)],
        color: empireColor,
      ),

      // Orphaned support: a support-of-attack whose supported move isn't in
      // this order set — the ghost must draw dotted and faint, never as a
      // confident attack arrow (arrows_overlay.js `supportedMoveMissing`).
      const Order(
        orderType: kOrderSupport,
        source: Offset(100, 500),
        aux: Offset(300, 500),
        target: Offset(550, 500),
        color: empireColor,
        orphanedSupport: true,
      ),

      // A resolved, successful convoy order — the fleet's own order, not
      // the army's move — drawn solid rather than dashed. Proves `result`
      // already drives the live dash pattern even though this ticket
      // doesn't draw the failed-order red outline yet (T16); a failed or
      // still-pending convoy would look identical to the dashed one above,
      // which is exactly the outline's job and exactly what's deferred.
      const Order(
        orderType: kOrderConvoy,
        source: Offset(900, 500), // fleet
        aux: Offset(750, 500), // army
        target: Offset(1050, 620), // destination
        color: empireColor,
        result: 0,
      ),
    ];

    const captions = [
      _Caption('Hold', Offset(40, 150)),
      _Caption('Move', Offset(310, 150)),
      _Caption('Support-to-hold', Offset(700, 150)),
      _Caption('Support-of-attack', Offset(60, 350)),
      _Caption('Convoyed move (2 fleets, submitted out of order)',
          Offset(700, 350)),
      _Caption('Orphaned support (dotted ghost)', Offset(40, 550)),
      _Caption('Resolved convoy order (solid)', Offset(760, 640)),
    ];

    final boundaryKey = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(
        body: RepaintBoundary(
          key: boundaryKey,
          child: Stack(
            children: [
              MapViewer(
                svgString: _syntheticSvg(),
                orders: orders,
                onProvinceTapped: (_) {},
              ),
              for (final c in captions)
                Positioned(
                  left: c.at.dx,
                  top: c.at.dy,
                  child: Text(
                    c.text,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
            ],
          ),
        ),
      ),
    ));

    // `_parseSvg` deliberately yields for 300 ms before parsing.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    final boundary = boundaryKey.currentContext!.findRenderObject()
        as RenderRepaintBoundary;
    late Uint8List png;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1.0);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      png = data!.buffer.asUint8List();
    });

    final out = Directory('build/map_render')..createSync(recursive: true);
    File('${out.path}/order_arrows.png').writeAsBytesSync(png);

    // Blankness sanity check, mirroring map_render_harness_test.dart's — a
    // PNG this small could not possibly contain seven drawn glyphs.
    expect(png.length, greaterThan(2000));
  });

  testWidgets(
      'T16: history mode draws the failure outline and dims the overlay; '
      'live mode draws the same orders with no result styling at all',
      (tester) async {
    tester.view.physicalSize = _canvasSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    const empireColor = Color(0xFFE3B457);

    // Every order here carries a `result` (or, for the hold, deliberately
    // doesn't) so the same list can be rendered twice: once with
    // `ordersFromHistory: true`, where `result` must drive the red halo and
    // the 0.85 opacity, and once with it left at the live default, where
    // `OrderArrowsPainter._isFailed` must stay gated off regardless of what
    // `result` says — a live order is never resolved.
    final orders = <Order>[
      // Successful move (result: 0) — solid, no halo, own colour only.
      const Order(
        orderType: kOrderMove,
        source: Offset(100, 100),
        target: Offset(350, 100),
        color: empireColor,
        result: 0,
      ),
      // Bounced move (result: 2 = ORDER_RESULT_BOUNCED) — red halo underneath,
      // arrow itself stays the empire colour.
      const Order(
        orderType: kOrderMove,
        source: Offset(500, 100),
        target: Offset(750, 100),
        color: empireColor,
        result: 2,
      ),
      // Hold the resolver never scored (result: null) — reads the same as
      // "succeeded": no halo, matching arrows_overlay.js's `!!o.result`
      // treating a falsy result (null or 0) as not failed.
      const Order(
        orderType: kOrderHold,
        source: Offset(1000, 100),
        color: empireColor,
      ),
      // Successful convoy (result: 0) — solid arc, no halo.
      const Order(
        orderType: kOrderConvoy,
        source: Offset(300, 300), // fleet
        aux: Offset(100, 300), // army
        target: Offset(550, 300),
        color: empireColor,
        result: 0,
      ),
      // Failed convoy (result: 1 = ORDER_RESULT_FAILED) — dashed arc, red
      // halo underneath.
      const Order(
        orderType: kOrderConvoy,
        source: Offset(900, 300), // fleet
        aux: Offset(700, 300), // army
        target: Offset(1150, 300),
        color: empireColor,
        result: 1,
      ),
      // Retreat, unresolved in this snapshot (result: null) — same glyph as
      // a move (T17's arrows_overlay.js dispatch), no halo.
      const Order(
        orderType: kOrderRetreat,
        source: Offset(100, 500),
        target: Offset(350, 500),
        color: empireColor,
      ),
    ];

    const captions = [
      _Caption('Move, result 0 (succeeded, no halo)', Offset(40, 150)),
      _Caption('Move, result 2 (bounced, red halo)', Offset(460, 150)),
      _Caption('Hold, result null (unscored, no halo)', Offset(900, 150)),
      _Caption('Convoy, result 0 (solid, no halo)', Offset(60, 350)),
      _Caption('Convoy, result 1 (dashed, red halo)', Offset(660, 350)),
      _Caption('Retreat, result null (same glyph as move)', Offset(40, 550)),
    ];

    Future<Uint8List> renderOnce(bool history, String label) async {
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: RepaintBoundary(
            key: boundaryKey,
            child: Stack(
              children: [
                MapViewer(
                  svgString: _syntheticSvg(),
                  orders: orders,
                  ordersFromHistory: history,
                  onProvinceTapped: (_) {},
                ),
                Positioned(
                  left: 40,
                  top: 20,
                  child: Text(label,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                ),
                for (final c in captions)
                  Positioned(
                    left: c.at.dx,
                    top: c.at.dy,
                    child: Text(
                      c.text,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ));

      // `_parseSvg` deliberately yields for 300 ms before parsing.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      final boundary = boundaryKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      late Uint8List png;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1.0);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        png = data!.buffer.asUint8List();
      });
      return png;
    }

    final out = Directory('build/map_render')..createSync(recursive: true);

    final historyPng = await renderOnce(true, 'HISTORY (0.85 opacity, red halo on failures)');
    File('${out.path}/order_arrows_history.png').writeAsBytesSync(historyPng);
    expect(historyPng.length, greaterThan(2000));

    final livePng = await renderOnce(
        false, 'LIVE (same orders — no result styling, 1.0 opacity)');
    File('${out.path}/order_arrows_live_unresolved.png').writeAsBytesSync(livePng);
    expect(livePng.length, greaterThan(2000));
  });
}
