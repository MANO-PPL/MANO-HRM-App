import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppDropdownItem<T> {
  final T value;
  final String label;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final String? badge;
  final Color? badgeColor;
  final Color? badgeTextColor;
  final bool isCustomAction;

  const AppDropdownItem({
    required this.value,
    required this.label,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.badge,
    this.badgeColor,
    this.badgeTextColor,
    this.isCustomAction = false,
  });
}

class AppCustomDropdown<T> extends FormField<T> {
  final String? labelText;
  final String hintText;
  final IconData? prefixIcon;
  final List<AppDropdownItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final bool isSearchable;
  final bool isDense;
  final Color? customFillColor;

  AppCustomDropdown({
    super.key,
    super.initialValue,
    this.labelText,
    this.hintText = 'Select an option',
    this.prefixIcon,
    required this.items,
    this.onChanged,
    this.isSearchable = false,
    this.isDense = false,
    this.customFillColor,
    super.enabled = true,
    super.validator,
    super.onSaved,
  }) : super(
          builder: (FormFieldState<T> state) {
            final context = state.context;
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final selectedValue = state.value;

            AppDropdownItem<T>? selectedItem;
            for (final item in items) {
              if (item.value == selectedValue) {
                selectedItem = item;
                break;
              }
            }

            final borderColor = state.hasError
                ? Colors.redAccent
                : isDark
                    ? const Color(0xFF30363D)
                    : const Color(0xFFCBD5E1);

            final bgColor = customFillColor ??
                (isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC));

            final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
            final textMuted = isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (labelText != null) ...[
                  Text(
                    labelText,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: state.widget.enabled
                        ? () async {
                            HapticFeedback.lightImpact();
                            final picked = await showModalBottomSheet<T>(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (sheetContext) => _AppCustomDropdownSheet<T>(
                                title: labelText ?? hintText,
                                items: items,
                                selectedValue: selectedValue,
                                isSearchable: isSearchable || items.length > 5,
                              ),
                            );

                            if (picked != null) {
                              state.didChange(picked);
                              onChanged?.call(picked);
                            }
                          }
                        : null,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: isDense ? 10 : 13,
                      ),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor, width: 1.2),
                      ),
                      child: Row(
                        children: [
                          if (selectedItem?.icon != null || prefixIcon != null) ...[
                            Icon(
                              selectedItem?.icon ?? prefixIcon,
                              size: 18,
                              color: selectedItem?.iconColor ??
                                  (isDark ? const Color(0xFF818CF8) : const Color(0xFF6366F1)),
                            ),
                            const SizedBox(width: 10),
                          ],
                          Expanded(
                            child: selectedItem != null
                                ? Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          selectedItem.label,
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: textPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (selectedItem.badge != null) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2.5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: selectedItem.badgeColor ??
                                                const Color(0xFF6366F1).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            selectedItem.badge!,
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: selectedItem.badgeTextColor ??
                                                  const Color(0xFF6366F1),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  )
                                : Text(
                                    hintText,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: textMuted,
                                      fontWeight: FontWeight.normal,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 20,
                            color: textMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (state.hasError) ...[
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      state.errorText ?? '',
                      style: GoogleFonts.inter(fontSize: 11, color: Colors.redAccent),
                    ),
                  ),
                ],
              ],
            );
          },
        );
}

class _AppCustomDropdownSheet<T> extends StatefulWidget {
  final String title;
  final List<AppDropdownItem<T>> items;
  final T? selectedValue;
  final bool isSearchable;

  const _AppCustomDropdownSheet({
    required this.title,
    required this.items,
    required this.selectedValue,
    required this.isSearchable,
  });

  @override
  State<_AppCustomDropdownSheet<T>> createState() => _AppCustomDropdownSheetState<T>();
}

class _AppCustomDropdownSheetState<T> extends State<_AppCustomDropdownSheet<T>> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textMuted = isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B);
    final sheetBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final itemHoverBg = isDark ? const Color(0xFF21262D) : const Color(0xFFF1F5F9);
    final borderColor = isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0);

    final filteredItems = widget.items.where((item) {
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return item.label.toLowerCase().contains(q) ||
          (item.subtitle != null && item.subtitle!.toLowerCase().contains(q)) ||
          (item.badge != null && item.badge!.toLowerCase().contains(q));
    }).toList();

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;
    final maxSheetHeight = (screenHeight - bottomInset) * 0.85;

    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: bottomInset),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutQuad,
      child: Container(
        constraints: BoxConstraints(maxHeight: maxSheetHeight),
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 25,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Sheet Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.layers_outlined,
                        size: 18,
                        color: Color(0xFF6366F1),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, size: 20, color: textMuted),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Optional Search Bar
              if (widget.isSearchable) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: GoogleFonts.inter(fontSize: 13, color: textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Search...',
                        hintStyle: GoogleFonts.inter(fontSize: 13, color: textMuted),
                        prefixIcon: Icon(Icons.search_rounded, size: 18, color: textMuted),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear, size: 16, color: textMuted),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ),
              ],

              const Divider(height: 1),

              // Items List
              Flexible(
                child: filteredItems.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 36),
                        child: Center(
                          child: Text(
                            'No options found',
                            style: GoogleFonts.inter(fontSize: 13, color: textMuted),
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: filteredItems.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final item = filteredItems[index];
                          final isSelected = item.value == widget.selectedValue;

                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                Navigator.pop(context, item.value);
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF6366F1).withValues(alpha: isDark ? 0.2 : 0.08)
                                      : itemHoverBg.withValues(alpha: isDark ? 0.4 : 0.6),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF6366F1).withValues(alpha: 0.6)
                                        : borderColor.withValues(alpha: 0.4),
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    if (item.icon != null) ...[
                                      Container(
                                        width: 34,
                                        height: 34,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? const Color(0xFF6366F1).withValues(alpha: 0.2)
                                              : (isDark ? const Color(0xFF21262D) : Colors.white),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isSelected
                                                ? const Color(0xFF6366F1).withValues(alpha: 0.4)
                                                : borderColor,
                                          ),
                                        ),
                                        child: Icon(
                                          item.icon,
                                          size: 18,
                                          color: isSelected
                                              ? const Color(0xFF6366F1)
                                              : (item.iconColor ?? (isDark ? Colors.white70 : Colors.grey.shade700)),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                    ],
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  item.label,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 13,
                                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                                    color: isSelected
                                                        ? (isDark ? Colors.white : const Color(0xFF4F46E5))
                                                        : textPrimary,
                                                  ),
                                                ),
                                              ),
                                              if (item.badge != null) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 2.5,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: item.badgeColor ??
                                                        const Color(0xFF6366F1).withValues(alpha: 0.15),
                                                    borderRadius: BorderRadius.circular(20),
                                                  ),
                                                  child: Text(
                                                    item.badge!,
                                                    style: GoogleFonts.inter(
                                                      fontSize: 10.5,
                                                      fontWeight: FontWeight.w600,
                                                      color: item.badgeTextColor ??
                                                          (isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5)),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          if (item.subtitle != null && item.subtitle!.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              item.subtitle!,
                                              style: GoogleFonts.inter(
                                                fontSize: 11,
                                                color: textMuted,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
                                        border: Border.all(
                                          color: isSelected ? const Color(0xFF6366F1) : textMuted.withValues(alpha: 0.5),
                                          width: isSelected ? 0 : 1.5,
                                        ),
                                      ),
                                      child: isSelected
                                          ? const Icon(
                                              Icons.check_rounded,
                                              size: 13,
                                              color: Colors.white,
                                            )
                                          : null,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
