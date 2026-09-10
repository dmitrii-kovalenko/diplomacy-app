// Regression guard for T13 (l10n of the consent sheet, auth, settings,
// account-linking and legal screens), widened by T10/T12's finishing pass to
// cover the board, chat and tournament screens those tickets converted.
//
// This originally checked only the files T13 converted: at the time it was
// written, the board (T10) and chat (T12) screens still carried hardcoded
// English literals of their own, and sweeping the whole tree would have
// failed this suite for regressions in screens no ticket had touched yet.
// Now that T10, T11, T12 and the tournament status labels (T24) have all
// converted their screens, this is the general guard the ticket originally
// asked for: every screen that carries player-facing copy is scanned.
//
// The match deliberately spans newlines. This codebase wraps anything long,
// so the copy that started all of this — a German `subtitle:` on one line
// with its string on the next — is invisible to a line-by-line scan, which
// is exactly how it survived review in the first place.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Files converted by T10, T11, T12, T13 and the T24 status-label fix.
const _scannedFiles = [
  'lib/screens/lobby/lobby_screen.dart',
  'lib/screens/lobby/create_game_screen.dart',
  'lib/screens/lobby/create_sandbox_screen.dart',
  'lib/screens/lobby/find_game_screen.dart',
  'lib/widgets/game_card.dart',
  'lib/main.dart',
  'lib/screens/auth/login_screen.dart',
  'lib/screens/auth/register_screen.dart',
  'lib/screens/auth/nickname_screen.dart',
  'lib/screens/settings/settings_screen.dart',
  'lib/screens/settings/link_account_screen.dart',
  'lib/screens/legal/legal_layout.dart',
  'lib/screens/legal/impressum_screen.dart',
  'lib/screens/legal/privacy_screen.dart',
  'lib/widgets/ui_kit.dart',
  'lib/screens/game/game_screen.dart',
  'lib/screens/game/preview_screen.dart',
  'lib/screens/chat/conversations_screen.dart',
  'lib/screens/chat/messages_screen.dart',
  'lib/screens/tournament/tournament_screen.dart',
];

/// Argument and statement positions that carry player-facing copy in this
/// codebase. `return` catches the label-helper pattern used throughout the
/// board and tournament screens (`_turnLabel`, `_tournamentStatusLabel`,
/// `_gameStatusLabel`) — a getter or a function with no `BuildContext` in
/// scope hands its caller a plain string, and that string is exactly as
/// player-facing as a `Text(...)` argument, just one call removed from it.
const _copyPositions = [
  'Text(',
  'title:',
  'subtitle:',
  'label:',
  'message:',
  'hint:',
  'hintText:',
  'tooltip:',
  'header:',
  'footer:',
  'intro:',
  'confirmLabel:',
  'cancelLabel:',
  'showToast(context,',
  'semanticsLabel:',
  'return',
];

/// Strings that sit in a copy position but are not translatable copy: the
/// product name, which stays untranslated by design; the nickname field's
/// placeholder, which the ticket allows to remain a fixed historical name;
/// and the legal screens' substantive prose, which stays English in every
/// locale on purpose (see the comment in each of those files — the Impressum
/// is placeholder data and there is no server-side policy to route to).
const _allowedContent = {
  'Hegemony',
  'HEGEMONY',
  'Talleyrand',
};

/// The legal screens' body prose is deliberately not localized. Rather than
/// enumerate every paragraph, exempt the two files' `LegalParagraph`/`body`
/// arguments by name — the chrome around them (titles, headings, labels) is
/// still scanned.
const _legalProseFiles = {
  'lib/screens/legal/impressum_screen.dart',
  'lib/screens/legal/privacy_screen.dart',
};

final _literalPattern = RegExp(
  '(${_copyPositions.map(RegExp.escape).join('|')})'
  r'''\s*(?:'([^'\\\n]{2,})'|"([^"\\\n]{2,})")''',
  multiLine: true,
);

void main() {
  test('the board, chat, tournament and T13 screens have no hardcoded '
      'English copy left', () {
    final violations = <String>[];

    for (final path in _scannedFiles) {
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: '$path should exist');

      final source = file.readAsStringSync();
      for (final match in _literalPattern.allMatches(source)) {
        final content = match.group(2) ?? match.group(3)!;
        // Only letters start copy; an asset path, a storage key or a format
        // string is not something a translator would ever see.
        if (!RegExp(r'^[A-Za-z]').hasMatch(content)) continue;
        if (_allowedContent.contains(content)) continue;
        if (_legalProseFiles.contains(path) && content.contains(' ')) continue;

        final line = '\n'.allMatches(source.substring(0, match.start)).length + 1;
        violations.add('$path:$line: ${match.group(0)!.trim()}');
      }
    }

    expect(violations, isEmpty,
        reason: 'Hardcoded copy found outside the allowlist:\n'
            '${violations.join('\n')}');
  });
}
