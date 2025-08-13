// lib/screens/personal_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_profile.dart';
import '../providers/user_provider.dart';

/// PersonalSettingsScreen:
/// - Select disability type
/// - Choose list-sort priority (1st, 2nd, 3rd)
/// - Toggle accessibility filters
/// - Save -> mark onboarding complete and go to /home
class PersonalSettingsScreen extends StatefulWidget {
  const PersonalSettingsScreen({super.key});

  @override
  State<PersonalSettingsScreen> createState() => _PersonalSettingsScreenState();
}

class _PersonalSettingsScreenState extends State<PersonalSettingsScreen> {
  // Disability type
  DisabilityType _disabilityType = DisabilityType.none;

  // Priority order (unique 3 items)
  // Default: personalized > rating > distance
  late List<SortKey> _priority;

  // Accessibility filter toggles
  bool _ramp = false;
  bool _restroom = false;
  bool _elevator = false;
  bool _braille = false;
  bool _guideDog = false;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // If the user already has preferences, preload them.
    final prof = context.read<UserProvider>().profile;
    final defaults = UserPreferences.defaults();

    _disabilityType = prof?.disabilityType ?? DisabilityType.none;

    final existingOrder = prof?.preferences.sortPriorityOrder;
    _priority = (existingOrder != null && existingOrder.isNotEmpty)
        ? List<SortKey>.from(existingOrder)
        : List<SortKey>.from(defaults.sortPriorityOrder);

    _ramp     = prof?.preferences.filterWheelchairRamp ?? false;
    _restroom = prof?.preferences.filterAccessibleRestroom ?? false;
    _elevator = prof?.preferences.filterElevator ?? false;
    _braille  = prof?.preferences.filterBrailleMenu ?? false;
    _guideDog = prof?.preferences.filterGuideDogFriendly ?? false;
  }

  // -----------------------------
  // Helpers
  // -----------------------------

  String _labelForDisability(DisabilityType t) {
    switch (t) {
      case DisabilityType.none:       return '해당 없음/기타';
      case DisabilityType.wheelchair: return '이동(휠체어) 장애';
      case DisabilityType.visual:     return '시각 장애';
      case DisabilityType.hearing:    return '청각 장애';
      case DisabilityType.cognitive:  return '인지/지적 장애';
      case DisabilityType.other:      return '기타';
    }
  }

  String _labelForSortKey(SortKey k) {
    switch (k) {
      case SortKey.personalized:  return '맞춤 추천';
      case SortKey.rating:        return '별점 높은 순';
      case SortKey.distance:      return '거리 가까운 순';
      case SortKey.accessibility: return '접근성 점수 높은 순';
    }
  }

  // Options excluding already selected keys (to keep uniqueness)
  List<SortKey> _optionsForIndex(int idx) {
    final all = SortKey.values;
    final used = <SortKey>{};
    for (int i = 0; i < _priority.length; i++) {
      if (i == idx) continue;
      used.add(_priority[i]);
    }
    return all.where((k) => !used.contains(k)).toList();
  }

  Widget _priorityDropdown(int idx, String title) {
    final current = _priority[idx];
    final options = _optionsForIndex(idx);
    if (!options.contains(current)) {
      // Ensure current selection is always in options
      options.insert(0, current);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        DropdownButtonFormField<SortKey>(
          value: current,
          items: options
              .map((k) =>
                  DropdownMenuItem(value: k, child: Text(_labelForSortKey(k))))
              .toList(),
          onChanged: (v) {
            if (v == null) return;
            setState(() {
              _priority[idx] = v;
            });
          },
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      // Build preferences
      final prefs = UserPreferences(
        sortPriorityOrder: List<SortKey>.from(_priority),
        filterWheelchairRamp: _ramp,
        filterAccessibleRestroom: _restroom,
        filterElevator: _elevator,
        filterBrailleMenu: _braille,
        filterGuideDogFriendly: _guideDog,
      );

      // Save via provider
      await context
          .read<UserProvider>()
          .markOnboardingComplete(prefs: prefs, disabilityType: _disabilityType);

      if (!mounted) return;
      // Go home
      Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('저장에 실패했어요. 네트워크를 확인해 주세요.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSave = !_saving;

    return Scaffold(
      appBar: AppBar(title: const Text('개인 설정(온보딩)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1) Disability type
          const Text('장애 유형 선택', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...DisabilityType.values.map((t) {
            return RadioListTile<DisabilityType>(
              value: t,
              groupValue: _disabilityType,
              onChanged: (v) => setState(() => _disabilityType = v!),
              title: Text(_labelForDisability(t)),
            );
          }),
          const SizedBox(height: 16),

          // 2) Sort priority (1st, 2nd, 3rd)
          const Text('정렬 우선순위 설정', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _priorityDropdown(0, '1순위'),
          const SizedBox(height: 12),
          _priorityDropdown(1, '2순위'),
          const SizedBox(height: 12),
          _priorityDropdown(2, '3순위'),
          const SizedBox(height: 16),

          // 3) Accessibility filters
          const Text('접근성 필터', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SwitchListTile(
            value: _ramp,
            onChanged: (v) => setState(() => _ramp = v),
            title: const Text('경사로(휠체어 램프) 있음'),
          ),
          SwitchListTile(
            value: _restroom,
            onChanged: (v) => setState(() => _restroom = v),
            title: const Text('장애인 화장실 있음'),
          ),
          SwitchListTile(
            value: _elevator,
            onChanged: (v) => setState(() => _elevator = v),
            title: const Text('엘리베이터 있음'),
          ),
          SwitchListTile(
            value: _braille,
            onChanged: (v) => setState(() => _braille = v),
            title: const Text('점자 메뉴 제공'),
          ),
          SwitchListTile(
            value: _guideDog,
            onChanged: (v) => setState(() => _guideDog = v),
            title: const Text('안내견 동반 가능'),
          ),
          const SizedBox(height: 24),

          // Preview (optional)
          Card(
            elevation: 0,
            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(.4),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('미리보기', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('장애유형: ${_labelForDisability(_disabilityType)}'),
                  Text('우선순위: '
                      '${_labelForSortKey(_priority[0])} > '
                      '${_labelForSortKey(_priority[1])} > '
                      '${_labelForSortKey(_priority[2])}'),
                  Text('필터: '
                      '${_ramp ? "램프 " : ""}'
                      '${_restroom ? "화장실 " : ""}'
                      '${_elevator ? "엘리베이터 " : ""}'
                      '${_braille ? "점자메뉴 " : ""}'
                      '${_guideDog ? "안내견" : ""}'
                      '${(!_ramp && !_restroom && !_elevator && !_braille && !_guideDog) ? "없음" : ""}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Save
          FilledButton.icon(
            icon: _saving
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check),
            label: Text(_saving ? '저장 중...' : '완료하고 시작하기'),
            onPressed: canSave ? _save : null,
          ),
          const SizedBox(height: 12),

          TextButton(
            onPressed: _saving
                ? null
                : () => Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false),
            child: const Text('나중에 설정할게요 (건너뛰기)'),
          ),
        ],
      ),
    );
  }
}

