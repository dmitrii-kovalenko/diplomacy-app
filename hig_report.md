# HIG Audit: diplomacy_app

**Generated**: 2026-09-08
**Project**: /Users/dmitrii/Coding/diplomacy_app
**Frameworks detected**: flutter
**Files scanned**: 33 code, 0 style, 1 config

**Quick stats**: 63 potential concerns, 10 positive patterns, 60 component usages detected across 4 HIG categories

## Instructions for AI Evaluator

You are reviewing a project for Apple Human Interface Guidelines compliance.
The HIG principles (accessibility, color systems, typography, responsive layout, motion) apply to all surfaces — native, web, and cross-platform.
For each category below, evaluate the code excerpts against the HIG reference material.

**Scoring**: Rate each category 1-10:
- **9-10**: Excellent HIG compliance, follows best practices
- **7-8**: Good compliance with minor improvements possible
- **5-6**: Partial compliance, several areas need attention
- **3-4**: Significant HIG violations
- **1-2**: Major violations or missing fundamental practices

**Output**: For each category, provide:
1. Score (1-10)
2. What's done well (cite specific code)
3. What needs improvement (cite specific file:line)
4. Specific fix recommendations

## Category: Foundations

*66 detections across 14 file(s) — 63 concern(s), 3 positive(s)*

### Code Excerpts

**lib/main\.dart**
~~~dart
L42: style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), // ⚠ concern
L121: seedColor: const Color(0xFFD4A54A), // Gold / amber for Diplomacy // ⚠ concern
L124: scaffoldBackgroundColor: const Color(0xFF1A1A2E), // ⚠ concern
L126: backgroundColor: Color(0xFF16213E), // ⚠ concern
L127: foregroundColor: Color(0xFFE0C97F), // ⚠ concern
L132: color: const Color(0xFF16213E), // ⚠ concern
L138: backgroundColor: const Color(0xFFD4A54A), // ⚠ concern
L139: foregroundColor: const Color(0xFF1A1A2E), // ⚠ concern
L147: fillColor: const Color(0xFF0F3460), // ⚠ concern
L232: backgroundColor: Color(0xFF1A1A2E), // ⚠ concern
L240: color: Color(0xFFD4A54A), // ⚠ concern
L246: fontSize: 32, // ⚠ concern
L248: color: Color(0xFFE0C97F), // ⚠ concern
L258: color: Color(0xFFD4A54A), // ⚠ concern
~~~

**lib/screens/chat/conversations\_screen\.dart**
~~~dart
L26: const Text('New Conversation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), // ⚠ concern
L89: trailing: unread > 0 ? CircleAvatar(radius: 12, child: Text('$unread', style: const TextStyle(fontSize: 12))) : null, // ⚠ concern
~~~

**lib/screens/chat/messages\_screen\.dart**
~~~dart
L41: if (isE2ee) const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.lock, color: Colors.green, size: 16)), // ⚠ concern
L60: color: isMine ? Colors.blue[100] : Colors.grey[200], // ⚠ concern
L66: if (!isMine) Text(msg['sender_empire_name'] ?? '', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)), // ⚠ concern
~~~

**lib/screens/game/game\_screen\.dart**
~~~dart
L194: color: Colors.orange[100], // ⚠ concern
L266: color: Colors.grey[200], // ⚠ concern
L282: color: Colors.blue[100], // ⚠ concern
L293: color: Colors.purple[100], // ⚠ concern
L319: title: Text('My Orders', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), // ⚠ concern
L339: icon: const Icon(Icons.delete, color: Colors.red), // ⚠ concern
~~~

**lib/screens/legal/impressum\_screen\.dart**
~~~dart
L17: style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold), // ⚠ concern
~~~

**lib/screens/legal/privacy\_screen\.dart**
~~~dart
L17: style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), // ⚠ concern
L22: style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold), // ⚠ concern
L34: style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold), // ⚠ concern
L47: style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold), // ⚠ concern
L60: style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold), // ⚠ concern
L72: style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold), // ⚠ concern
L82: style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold), // ⚠ concern
~~~

**lib/screens/lobby/lobby\_screen\.dart**
~~~dart
L63: height: MediaQuery.of(context).size.height * 0.8, // ✓ good
L133: child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), // ⚠ concern
~~~

**lib/screens/settings/link\_account\_screen\.dart**
~~~dart
L155: style: Theme.of(context).textTheme.headlineLarge?.copyWith( // ✓ good
L161: Text('Expires in: $_timeLeft', style: const TextStyle(color: Colors.red)), // ⚠ concern
L194: style: const TextStyle(letterSpacing: 8.0, fontSize: 24), // ⚠ concern
~~~

**lib/screens/settings/settings\_screen\.dart**
~~~dart
L34: TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reset', style: TextStyle(color: Colors.red))), // ⚠ concern
L104: child: const Text('Konto löschen', style: TextStyle(color: Colors.red)), // ⚠ concern
L178: leading: const Icon(Icons.refresh, color: Colors.red), // ⚠ concern
L179: title: const Text('Reset Key Pair', style: TextStyle(color: Colors.red)), // ⚠ concern
L229: leading: const Icon(Icons.delete_forever, color: Colors.red), // ⚠ concern
L230: title: const Text('Konto löschen', style: TextStyle(color: Colors.red)), // ⚠ concern
~~~

**lib/screens/tournament/tournament\_screen\.dart**
~~~dart
L76: Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)), // ⚠ concern
L85: label: Text('Registered. Waiting for shuffle.', style: TextStyle(color: Colors.white)), // ⚠ concern
L86: backgroundColor: Colors.green, // ⚠ concern
L95: label: Text('Registered', style: TextStyle(color: Colors.white)), // ⚠ concern
L96: backgroundColor: Colors.blue, // ⚠ concern
L105: child: Text('Tournament Games', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), // ⚠ concern
~~~

**lib/widgets/game\_card\.dart**
~~~dart
L36: style: Theme.of(context).textTheme.titleLarge, // ✓ good
~~~

**lib/widgets/map\_viewer\.dart**
~~~dart
L183: ..color = provinceColors[provinceId] ?? Colors.white // ⚠ concern
L188: ..color = Colors.black // ⚠ concern
L202: style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold), // ⚠ concern
L202: style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold), // ⚠ concern
L213: _drawStar(canvas, offset, Colors.yellow); // simplified SC marker // ⚠ concern
L220: final color = provinceColors[provinceId] ?? Colors.grey; // ⚠ concern
L228: ..color = Colors.black // ⚠ concern
L261: canvas.drawCircle(center, 5, Paint()..color = Colors.black..style = PaintingStyle.stroke); // ⚠ concern
~~~

**lib/widgets/order\_arrows\.dart**
~~~dart
L59: ..color = Colors.black // ⚠ concern
L86: _drawArrowHead(canvas, ctrlX, ctrlY, end.dx, end.dy, Colors.black); // ⚠ concern
L91: ..color = Colors.green // ⚠ concern
L117: _drawArrowHead(canvas, start.dx, start.dy, end.dx, end.dy, Colors.green); // ⚠ concern
L122: ..color = Colors.blue // ⚠ concern
L127: _drawArrowHead(canvas, start.dx, start.dy, end.dx, end.dy, Colors.blue); // ⚠ concern
~~~

**web/index\.html**
~~~html
L2: <html> // ⚠ concern
~~~

### HIG Reference

*Load reference from skill: hig-foundations*

### Evaluate

- Color usage: system semantic colors vs hardcoded values
- Typography: Dynamic Type text styles vs fixed font sizes
- Accessibility: labels, hints, traits on interactive elements
- Dark mode: proper color adaptation, no hardcoded light/dark values
- Motion: Reduce Motion support for animations

## Category: Layout & Navigation

*39 detections across 13 file(s) — 0 concern(s), 0 positive(s)*

### Code Excerpts

**lib/main\.dart**
~~~dart
L65: onPressed: () => Navigator.of(ctx).pop(analyticsEnabled),
L224: Navigator.of(context).pushReplacement(
~~~

**lib/screens/auth/login\_screen\.dart**
~~~dart
L74: Navigator.of(context).pushReplacement(
L78: Navigator.of(context).pushReplacement(
L138: Navigator.push(
~~~

**lib/screens/auth/nickname\_screen\.dart**
~~~dart
L30: Navigator.pushReplacement(
~~~

**lib/screens/auth/register\_screen\.dart**
~~~dart
L41: Navigator.pop(context); // Go back to login screen on success
~~~

**lib/screens/chat/conversations\_screen\.dart**
~~~dart
L51: Navigator.pop(ctx);
L75: return ListView.builder(
L91: Navigator.push(context, MaterialPageRoute(builder: (_) => MessagesScreen(bloc: bloc, conversationId: conv['id'])));
~~~

**lib/screens/chat/messages\_screen\.dart**
~~~dart
L48: child: ListView.builder(
~~~

**lib/screens/game/game\_screen\.dart**
~~~dart
L68: TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
L69: TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes')),
L122: Navigator.pop(context);
L130: Navigator.pop(context);
L328: child: ListView.builder(
~~~

**lib/screens/lobby/create\_game\_screen\.dart**
~~~dart
L64: if (mounted) Navigator.pop(context);
L90: : ListView(
~~~

**lib/screens/lobby/create\_sandbox\_screen\.dart**
~~~dart
L45: if (mounted) Navigator.pop(context);
~~~

**lib/screens/lobby/lobby\_screen\.dart**
~~~dart
L17: Navigator.of(context).pushReplacement(
L35: Navigator.push(
L59: child: ListView(
L73: child: ListView(
L94: await Navigator.push(
L108: await Navigator.push(
~~~

**lib/screens/settings/link\_account\_screen\.dart**
~~~dart
L102: Navigator.of(context).pushAndRemoveUntil(
~~~

**lib/screens/settings/settings\_screen\.dart**
~~~dart
L33: TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
L34: TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reset', style: TextStyle(color: Colors.red))),
L62: onPressed: () => Navigator.pop(ctx, l),
L85: Navigator.of(context).popUntil((route) => route.isFirst);
L99: onPressed: () => Navigator.pop(ctx, false),
L103: onPressed: () => Navigator.pop(ctx, true),
L114: Navigator.of(context).pushAndRemoveUntil(
L152: body: ListView(
L165: Navigator.of(context).push(
L199: onTap: () => Navigator.of(context).push(
L206: onTap: () => Navigator.of(context).push(
L213: onTap: () => Navigator.of(context).push(
~~~

**lib/screens/tournament/tournament\_screen\.dart**
~~~dart
L108: child: ListView.builder(
~~~

### HIG Reference

*Load reference from skill: hig-components-layout*

### Evaluate

- Navigation pattern matches app structure (tabs for flat, sidebar for deep)
- Adaptive layout: responds to size classes, multitasking
- Standard navigation components (NavigationSplitView, not deprecated NavigationView)
- Consistent back navigation and spatial hierarchy

## Category: Controls

*21 detections across 12 file(s) — 0 concern(s), 0 positive(s)*

### Code Excerpts

**lib/main\.dart**
~~~dart
L64: child: ElevatedButton(
L137: style: ElevatedButton.styleFrom(
~~~

**lib/screens/auth/login\_screen\.dart**
~~~dart
L123: ElevatedButton(
L128: ElevatedButton(
L132: ElevatedButton(
~~~

**lib/screens/auth/nickname\_screen\.dart**
~~~dart
L69: else ElevatedButton(
~~~

**lib/screens/auth/register\_screen\.dart**
~~~dart
L89: else ElevatedButton(
~~~

**lib/screens/chat/conversations\_screen\.dart**
~~~dart
L48: ElevatedButton(
~~~

**lib/screens/game/game\_screen\.dart**
~~~dart
L271: ElevatedButton(onPressed: () => bloc.setAction(ActionType.hold), child: const Text('Hold')),
L272: ElevatedButton(onPressed: () => bloc.setAction(ActionType.move), child: const Text('Move')),
L273: ElevatedButton(onPressed: () => bloc.setAction(ActionType.support), child: const Text('Support')),
L274: ElevatedButton(onPressed: () => bloc.setAction(ActionType.convoy), child: const Text('Convoy')),
L275: ElevatedButton(onPressed: () => _showBuildModal(context, bloc), child: const Text('Build...')),
~~~

**lib/screens/lobby/create\_game\_screen\.dart**
~~~dart
L144: ElevatedButton(
~~~

**lib/screens/lobby/create\_sandbox\_screen\.dart**
~~~dart
L77: ElevatedButton(
~~~

**lib/screens/lobby/find\_game\_screen\.dart**
~~~dart
L68: ElevatedButton(
~~~

**lib/screens/settings/link\_account\_screen\.dart**
~~~dart
L163: ElevatedButton(
L197: ElevatedButton(
~~~

**lib/screens/tournament/tournament\_screen\.dart**
~~~dart
L89: ElevatedButton(
~~~

**lib/widgets/game\_card\.dart**
~~~dart
L57: ElevatedButton(
L62: ElevatedButton(
~~~

### HIG Reference

*Load reference from skill: hig-components-controls*

### Evaluate

- Standard control usage (Button, Toggle, Picker, etc.)
- Proper button styles and roles
- Clear action labels and consistent interaction patterns

## Category: Interaction Patterns

*7 detections across 5 file(s) — 0 concern(s), 7 positive(s)*

### Code Excerpts

**lib/main\.dart**
~~~dart
L4: import 'package:flutter_localizations/flutter_localizations.dart'; // ✓ good
L153: AppLocalizations.delegate, // ✓ good
L158: supportedLocales: AppLocalizations.supportedLocales, // ✓ good
~~~

**lib/screens/auth/login\_screen\.dart**
~~~dart
L101: final loc = AppLocalizations.of(context)!; // ✓ good
~~~

**lib/screens/auth/register\_screen\.dart**
~~~dart
L64: final loc = AppLocalizations.of(context)!; // ✓ good
~~~

**lib/screens/lobby/create\_game\_screen\.dart**
~~~dart
L85: final loc = AppLocalizations.of(context)!; // ✓ good
~~~

**lib/screens/settings/settings\_screen\.dart**
~~~dart
L148: final loc = AppLocalizations.of(context)!; // ✓ good
~~~

### HIG Reference

*Load reference from skill: hig-patterns*

### Evaluate

- Drag and drop support where appropriate
- Pull-to-refresh for refreshable content
- Swipe actions follow HIG conventions
- Undo support for destructive actions

## Scoring Summary

| Category | Score (1-10) | Key Findings |
|----------|-------------|-------------|
| Foundations | | |
| Layout & Navigation | | |
| Controls | | |
| Interaction Patterns | | |
| **Overall** | **/10** | |
