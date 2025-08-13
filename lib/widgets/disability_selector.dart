// lib/widgets/disability_selector.dart
import 'package:flutter/material.dart';
import '../models/user_profile.dart';

/// Centralized labels/icons for DisabilityType.
/// Use these helpers anywhere (e.g., previews).
class DisabilityLabels {
  static String labelOf(DisabilityType t) {
    switch (t) {
      case DisabilityType.none:       return '해당 없음/기타';
      case DisabilityType.wheelchair: return '이동(휠체어) 장애';
      case DisabilityType.visual:     return '시각 장애';
      case DisabilityType.hearing:    return '청각 장애';
      case DisabilityType.cognitive:  return '인지/지적 장애';
      case DisabilityType.other:      return '기타';
    }
  }

  static IconData iconOf(DisabilityType t) {
    switch (t) {
      case DisabilityType.none:       return Icons.person_outline;
      case DisabilityType.wheelchair: return Icons.accessible;     // Material icon for mobility
      case DisabilityType.visual:     return Icons.visibility_off; // visual impairment
      case DisabilityType.hearing:    return Icons.hearing;        // hearing impairment
      case DisabilityType.cognitive:  return Icons.psychology;     // cognitive
      case DisabilityType.other:      return Icons.help_outline;
    }
  }

  static String? descriptionOf(DisabilityType t) {
    switch (t) {
      case DisabilityType.none:       return '특정 지원 사항 없음 또는 기타';
      case DisabilityType.wheelchair: return '경사로·엘리베이터 등 이동 접근성 중심';
      case DisabilityType.visual:     return '점자·고대비·음성 안내 등 시각 접근성';
      case DisabilityType.hearing:    return '자막·시각 알림 등 청각 접근성';
      case DisabilityType.cognitive:  return '간결한 안내·쉬운 탐색 등 인지 접근성';
      case DisabilityType.other:      return '그 외 맞춤 접근성';
    }
  }
}

/// A reusable single-select widget for DisabilityType.
/// - Default layout uses ChoiceChips in a wrap (compact & touch-friendly)
/// - Parent owns the state: pass `value` & handle `onChanged`
/// - Set [readOnly] to true to disable interaction
class DisabilitySelector extends StatelessWidget {
  final DisabilityType value;
  final ValueChanged<DisabilityType> onChanged;
  final bool readOnly;
  final bool showDescriptions; // small caption under the chips
  final EdgeInsetsGeometry padding;
  final double chipSpacing;
  final double runSpacing;

  const DisabilitySelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.readOnly = false,
    this.showDescriptions = false,
    this.padding = const EdgeInsets.symmetric(vertical: 4),
    this.chipSpacing = 8,
    this.runSpacing = 8,
  });

  @override
  Widget build(BuildContext context) {
    final chips = DisabilityType.values.map((t) {
      final selected = value == t;
      return Semantics(
        button: true,
        selected: selected,
        label: DisabilityLabels.labelOf(t),
        hint: selected ? '선택됨' : '선택하려면 두 번 탭',
        child: ChoiceChip(
          label: Text(DisabilityLabels.labelOf(t)),
          avatar: Icon(DisabilityLabels.iconOf(t), size: 18),
          selected: selected,
          onSelected: readOnly ? null : (_) => onChanged(t),
          // Material 3 uses surface/primary by theme; looks good without manual colors.
          // You can customize styles here if needed.
        ),
      );
    }).toList();

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: chipSpacing,
            runSpacing: runSpacing,
            children: chips,
          ),
          if (showDescriptions) ...[
            const SizedBox(height: 8),
            Text(
              DisabilityLabels.descriptionOf(value) ?? '',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

/// Form-friendly version for use inside `Form` widgets.
/// Example:
/// ```dart
/// Form(
///   child: DisabilitySelectorFormField(
///     initialValue: DisabilityType.none,
///     onSaved: (v) => ...,
///   ),
/// )
/// ```
class DisabilitySelectorFormField extends FormField<DisabilityType> {
  DisabilitySelectorFormField({
    super.key,
    DisabilityType initialValue = DisabilityType.none,
    bool autovalidate = false,
    FormFieldSetter<DisabilityType>? onSaved,
    FormFieldValidator<DisabilityType>? validator,
    ValueChanged<DisabilityType>? onChanged,
    bool readOnly = false,
    bool showDescriptions = false,
  }) : super(
          initialValue: initialValue,
          onSaved: onSaved,
          validator: validator,
          builder: (state) {
            final current = state.value ?? DisabilityType.none;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DisabilitySelector(
                  value: current,
                  readOnly: readOnly,
                  showDescriptions: showDescriptions,
                  onChanged: (v) {
                    state.didChange(v);
                    onChanged?.call(v);
                  },
                ),
                if (state.hasError)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      state.errorText!,
                      style: TextStyle(
                        color: Theme.of(state.context).colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            );
          },
        );
}

