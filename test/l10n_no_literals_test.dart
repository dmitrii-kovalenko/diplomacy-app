// Regression guard for T13 (l10n of the consent sheet, auth, settings,
// account-linking and legal screens).
//
// This intentionally checks only the files T13 converted, not the whole of
// lib/screens/ and lib/widgets/: at the time this test was written, the
// board (T10) and chat (T12) screens still carry hardcoded English literals
// of their own. Sweeping the whole tree would fail this suite for
// regressions in screens this ticket never touched. Once those tickets
// convert their screens, widening `_scannedFiles` turns this into the
// general guard the ticket originally asked for.
//
// The match deliberately spans newlines. This codebase wraps anything long,
// so the copy that started all of this — a German `subtitle:` on one line
// with its string on the next — is invisible to a line-by-line scan, which
// is exactly how it survived review in the first place.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Files this ticket localized.
const _scannedFiles = [
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
];

/// Argument positions that carry player-facing copy in this codebase.
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
  test('T13 screens have no hardcoded English copy left', () {
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
