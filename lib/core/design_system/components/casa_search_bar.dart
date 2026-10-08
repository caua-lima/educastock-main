import 'package:flutter/material.dart';
import '../tokens/color_tokens.dart';
import '../tokens/spacing_tokens.dart';
import '../tokens/typography_tokens.dart';

class CasaSearchBar extends StatelessWidget {
  final TextEditingController? controller;
  final String hint;
  final void Function(String)? onChanged;
  final VoidCallback? onFilter;
  final bool showFilter;

  const CasaSearchBar({
    super.key,
    this.controller,
    this.hint = 'Buscar...',
    this.onChanged,
    this.onFilter,
    this.showFilter = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: AppColors.neutral100, width: 1.5),
            ),
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: AppTypography.bodyMedium.copyWith(color: AppColors.neutral900),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle:
                    AppTypography.bodyMedium.copyWith(color: AppColors.neutral500),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppColors.neutral500, size: 20),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
              ),
            ),
          ),
        ),
        if (showFilter) ...[
          const SizedBox(width: AppSpacing.sm),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.brandPrimary100,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: IconButton(
              icon: const Icon(Icons.tune_rounded,
                  color: AppColors.brandPrimary600, size: 20),
              onPressed: onFilter,
            ),
          ),
        ],
      ],
    );
  }
}
