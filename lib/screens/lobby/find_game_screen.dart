import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../models/game_model.dart';
import '../../services/lobby_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/game_card.dart';
import '../../widgets/ui_kit.dart';
import '../game/preview_screen.dart';

/// Joining by code. One field, one action, one result — so the field is the
/// hero: tall, centre-aligned, tracked out so a six-character code reads as
/// six discrete characters.
class FindGameScreen extends StatefulWidget {
  const FindGameScreen({super.key});

  @override
  State<FindGameScreen> createState() => _FindGameScreenState();
}

class _FindGameScreenState extends State<FindGameScreen> {
  final _shareIdController = TextEditingController();
  final _lobbyService = LobbyService();
  bool _isLoading = false;
  bool _searched = false;
  GameModel? _foundGame;

  @override
  void initState() {
    super.initState();
    _shareIdController.addListener(() => setState(() {}));
  }

  Future<void> _search() async {
    final shareId = _shareIdController.text.trim();
    if (shareId.isEmpty) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _foundGame = null;
    });

    try {
      final data = await _lobbyService.findGame(shareId);
      if (!mounted) return;
      setState(() => _foundGame = GameModel.fromJson(data['game']));
    } catch (e) {
      if (mounted) {
        showToast(
            context, AppLocalizations.of(context)!.findRoomNotFoundToast,
            isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _searched = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _shareIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;
    final code = _shareIdController.text.trim();

    return Scaffold(
      appBar: AppBar(title: Text(loc.findRoomTitle)),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
        children: [
          const SizedBox(height: AppSpacing.xl),
          Text(
            loc.findRoomInstructions,
            style: t.bodyMedium?.copyWith(color: c.labelSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xxl),
          Container(
            decoration: BoxDecoration(
              color: c.bgElevated,
              borderRadius: AppRadius.brLg,
              border:
                  Border.all(color: c.separator, width: AppMetrics.hairline),
            ),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: TextField(
              controller: _shareIdController,
              autofocus: true,
              maxLength: 6,
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.go,
              onSubmitted: (_) => _search(),
              cursorColor: c.accent,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                TextInputFormatter.withFunction((_, next) => next.copyWith(
                    text: next.text.toUpperCase())),
              ],
              style: t.displayMedium?.copyWith(
                letterSpacing: 10,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              decoration: InputDecoration(
                counterText: '',
                hintText: '••••••',
                hintStyle: t.displayMedium?.copyWith(
                    color: c.labelQuaternary, letterSpacing: 10),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg, vertical: AppSpacing.md),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            loc.findRoomButton,
            icon: CupertinoIcons.search,
            loading: _isLoading,
            onPressed: code.isEmpty ? null : _search,
          ),
          const SizedBox(height: AppSpacing.xxl),
          if (_foundGame != null) ...[
            Padding(
              padding: const EdgeInsets.only(
                  left: AppSpacing.xs, bottom: AppSpacing.md),
              child: Text(loc.findRoomFoundLabel,
                  style: t.labelSmall
                      ?.copyWith(color: c.labelSecondary, letterSpacing: 0.6)),
            ),
            GameCard(
              game: _foundGame!,
              margin: EdgeInsets.zero,
              onEnter: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        GamePreviewScreen(gameId: _foundGame!.id)),
              ),
            ),
          ] else if (_searched && !_isLoading)
            AppEmptyState(
              icon: CupertinoIcons.search,
              title: loc.findRoomEmptyTitle,
              message: loc.findRoomEmptyMessage,
            ),
        ],
      ),
    );
  }
}
