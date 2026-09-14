import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../constants/languages.dart';
import '../theme/app_theme.dart';

class LanguagePickerSheet extends StatefulWidget {
  final SyncDubLanguage selectedLanguage;
  final ValueChanged<SyncDubLanguage> onSelected;
  final bool isDark;

  const LanguagePickerSheet({
    super.key,
    required this.selectedLanguage,
    required this.onSelected,
    this.isDark = false,
  });

  static Future<void> show({
    required BuildContext context,
    required SyncDubLanguage selectedLanguage,
    required ValueChanged<SyncDubLanguage> onSelected,
    bool isDark = false,
    bool? isDarkMode,
  }) {
    final effectiveDark = isDarkMode ?? isDark;
    final surfaceColor = effectiveDark ? AppTheme.darkSurface : AppTheme.lightSurface;

    return showModalBottomSheet(
      context: context,
      backgroundColor: surfaceColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => LanguagePickerSheet(
        selectedLanguage: selectedLanguage,
        onSelected: onSelected,
        isDark: effectiveDark,
      ),
    );
  }

  @override
  State<LanguagePickerSheet> createState() => _LanguagePickerSheetState();
}

class _LanguagePickerSheetState extends State<LanguagePickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<SyncDubLanguage> _filteredLanguages = kSupportedLanguages;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredLanguages = kSupportedLanguages;
      } else {
        _filteredLanguages = kSupportedLanguages
            .where((l) =>
                l.name.toLowerCase().contains(query) ||
                l.code.toLowerCase().contains(query) ||
                l.abbr.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fg = AppTheme.textPrimary(widget.isDark);
    final fg3 = AppTheme.textMuted(widget.isDark);
    final bd = AppTheme.border(widget.isDark);
    final inputBg = AppTheme.surface2(widget.isDark);

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: bd,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select Target Language',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: fg,
                    letterSpacing: -0.2,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 20, color: fg3),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Search Input
            TextField(
              controller: _searchController,
              style: TextStyle(color: fg, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search languages...',
                hintStyle: TextStyle(color: fg3, fontSize: 13),
                prefixIcon: Icon(Icons.search, size: 19, color: fg3),
                filled: true,
                fillColor: inputBg,
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: bd),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: bd),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.emerald, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _filteredLanguages.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  thickness: 1,
                  color: bd.withValues(alpha: 0.6),
                ),
                itemBuilder: (context, index) {
                  final lang = _filteredLanguages[index];
                  final isSelected = lang.code == widget.selectedLanguage.code;

                  return InkWell(
                    onTap: () {
                      widget.onSelected(lang);
                      Navigator.pop(context);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.emeraldDim : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Text(
                            lang.flag,
                            style: const TextStyle(fontSize: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  lang.name,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: fg,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  lang.code,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: fg3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            const Icon(
                              Iconsax.tick_circle,
                              size: 18,
                              color: AppTheme.emerald,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
