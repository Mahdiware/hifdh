import 'package:flutter/material.dart';
import 'package:hifdh/core/theme/app_background.dart';
import 'package:hifdh/shared/models/result_item.dart';
import 'package:hifdh/shared/widgets/theme_toggle_button.dart';
import 'package:hifdh/core/utils/surah_glyphs.dart';
import 'package:hifdh/l10n/generated/app_localizations.dart';
import 'package:hifdh/shared/widgets/liquid_glass.dart';

class ResultPage extends StatelessWidget {
  final List<ResultItem> results;

  const ResultPage({super.key, required this.results});

  @override
  Widget build(BuildContext context) {
    int correctCount = results.where((r) => r.isCorrect).length;
    int totalCount = results.length;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    double percent = totalCount == 0 ? 0 : (correctCount / totalCount);

    Color scoreColor = percent >= 0.8
        ? Colors.green
        : percent >= 0.5
        ? Colors.orange
        : Colors.red;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: DecoratedBox(
        decoration: AppBackground.pageDecoration(theme),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildQuizHeader(context, isDark)),
              SliverToBoxAdapter(
                child: _buildScoreSection(
                  context,
                  percent,
                  scoreColor,
                  correctCount,
                  totalCount,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Text(
                        AppLocalizations.of(context)!.detailedReview,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      LiquidGlass(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        blur: 14,
                        tint: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.white.withValues(alpha: 0.56),
                        child: Text(
                          AppLocalizations.of(
                            context,
                          )!.questionsCount(totalCount),
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final item = results[index];
                  return _ResultItemCard(item: item);
                }, childCount: results.length),
              ),
              const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScoreSection(
    BuildContext context,
    double percent,
    Color scoreColor,
    int correctCount,
    int totalCount,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: LiquidGlass(
        padding: const EdgeInsets.all(24),
        borderRadius: BorderRadius.circular(24),
        blur: 20,
        gradient: LinearGradient(
          colors: [
            scoreColor.withValues(alpha: isDark ? 0.24 : 0.16),
            Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: isDark ? 0.16 : 0.10),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: scoreColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.auto_graph_rounded,
                    color: scoreColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.score,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                LiquidGlass(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  borderRadius: BorderRadius.circular(999),
                  blur: 8,
                  tint: scoreColor.withValues(alpha: isDark ? 0.2 : 0.14),
                  border: Border.all(color: scoreColor.withValues(alpha: 0.28)),
                  child: Text(
                    '$correctCount/$totalCount',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: scoreColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: percent),
              duration: const Duration(milliseconds: 1500),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 140,
                      height: 140,
                      child: CircularProgressIndicator(
                        value: value,
                        strokeWidth: 14,
                        backgroundColor: scoreColor.withValues(alpha: 0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${(value * 100).round()}%',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: scoreColor,
                          ),
                        ),
                        Text(
                          AppLocalizations.of(context)!.score,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context,
                    AppLocalizations.of(context)!.correct,
                    correctCount.toString(),
                    Colors.green,
                    Icons.check_circle_outline,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    context,
                    AppLocalizations.of(context)!.wrong,
                    (totalCount - correctCount).toString(),
                    Colors.red,
                    Icons.cancel_outlined,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LiquidGlass(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      borderRadius: BorderRadius.circular(16),
      blur: 12,
      tint: color.withValues(alpha: isDark ? 0.16 : 0.09),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          color.withValues(alpha: isDark ? 0.2 : 0.1),
          color.withValues(alpha: isDark ? 0.1 : 0.05),
        ],
      ),
      border: Border.all(color: color.withValues(alpha: 0.24)),
      child: Column(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: color.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizHeader(BuildContext context, bool isDark) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: LiquidGlass(
        padding: const EdgeInsets.all(8),
        borderRadius: BorderRadius.circular(18),
        blur: 16,
        tint: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.72),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
        child: Row(
          children: [
            IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: theme.colorScheme.onSurface,
              ),
              onPressed: () => Navigator.pop(context),
              tooltip: AppLocalizations.of(context)!.back,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.quizResults,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    AppLocalizations.of(context)!.detailedReview,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? Colors.white70 : const Color(0xFF4F6581),
                    ),
                  ),
                ],
              ),
            ),
            const ThemeToggleButton(),
          ],
        ),
      ),
    );
  }
}

class _ResultItemCard extends StatefulWidget {
  final ResultItem item;

  const _ResultItemCard({required this.item});

  @override
  State<_ResultItemCard> createState() => _ResultItemCardState();
}

class _ResultItemCardState extends State<_ResultItemCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isCorrect = item.isCorrect;
    final color = isCorrect ? Colors.green : Colors.red;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: LiquidGlass(
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(16),
        blur: 14,
        tint: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.58),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.12),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: _isExpanded
                    ? color.withValues(alpha: isDark ? 0.15 : 0.07)
                    : Colors.transparent,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Icon
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isCorrect ? Icons.check : Icons.close,
                          color: color,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              Localizations.localeOf(context).languageCode ==
                                  'ar'
                              ? CrossAxisAlignment.start
                              : CrossAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "${AppLocalizations.of(context)!.ayah} ${item.ayah.ayahNumber}",
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).textTheme.bodySmall?.color,
                                      ),
                                ),
                                Text(
                                  SurahGlyphs.list[item.ayah.surahNumber - 1],
                                  style: TextStyle(
                                    fontFamily: 'SurahFont',
                                    fontSize: 24,
                                    color: Theme.of(
                                      context,
                                    ).textTheme.bodyLarge?.color,
                                    height: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item.ayah.text,
                              maxLines: _isExpanded ? null : 1,
                              overflow: _isExpanded
                                  ? TextOverflow.visible
                                  : TextOverflow.ellipsis,
                              textDirection: TextDirection.rtl,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontFamily: 'QuranFont',
                                fontSize: 20,
                                height: 1.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Center(
                      child: AnimatedRotation(
                        duration: const Duration(milliseconds: 180),
                        turns: _isExpanded ? 0.5 : 0,
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          size: 18,
                          color: Theme.of(
                            context,
                          ).iconTheme.color?.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
