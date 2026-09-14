import 'package:flutter/material.dart';

import '../../core/theme/design_tokens.dart';
import '../../core/theme/palette.dart';

/// Shared text-field style used across sheets and pages.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    this.hint,
    this.maxLength,
    this.prefix,
    this.focusNode,
    this.autofocus = false,
    this.keyboardType,
    this.minLines = 1,
    this.maxLines = 1,
    this.onChanged,
  });

  final TextEditingController controller;
  final String? hint;
  final int? maxLength;
  final Widget? prefix;
  final FocusNode? focusNode;
  final bool autofocus;
  final TextInputType? keyboardType;
  final int minLines;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      keyboardType: keyboardType,
      minLines: minLines,
      maxLines: maxLines,
      maxLength: maxLength,
      onChanged: onChanged,
      style: Theme.of(context).textTheme.bodyLarge,
      cursorColor: c.primary,
      decoration: InputDecoration(
        counterText: '',
        hintText: hint,
        hintStyle: Theme.of(context)
            .textTheme
            .bodyLarge
            ?.copyWith(color: c.inkFaint),
        prefixIcon: prefix == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(left: Sp.lg, right: Sp.md),
                child: prefix!,
              ),
        prefixIconConstraints:
            const BoxConstraints(),
        filled: true,
        fillColor: c.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: Sp.lg, vertical: 15),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.m),
          borderSide: BorderSide(color: c.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.m),
          borderSide: BorderSide(color: c.primary, width: 1.6),
        ),
      ),
    );
  }
}
