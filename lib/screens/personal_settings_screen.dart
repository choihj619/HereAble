// lib/screens/personal_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_profile.dart';
import '../providers/user_provider.dart';

class PersonalSettingsScreen extends StatefulWidget {
  const PersonalSettingsScreen({super.key});

  @override
  State<PersonalSettingsScreen> createState() => _PersonalSettingsScreenState();
}

class _PersonalSettingsScreenState extends State<PersonalSettingsScreen> {
  DisabilityType _disabilityType = DisabilityType.none;
  late List<SortKey> _priority;

  bool _ramp = false;
  bool _restroom = false;
  bool _elevator = false;
  bool _braille = false;
  bool _guideDog = false;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final prof = context.read<UserProvider>().profile;
    final defaults = UserPreferences.defaults();

    _disabilityType = prof?.disabilityType ?? DisabilityType.none;
    _priority = prof?.preferences.sortPriorityOrder.isNotEmpty == true
        ? List<SortKey>.from(prof!.preferences.sortPriorityOrder)
        : List<SortKey>.from(defaults.sortPriorityOrder);

    _ramp = prof?.preferences.filterWheelchairRamp ?? false;
    _restroom = prof?.preferences.filterAccessibleRestroom ?? false;
    _elevator = prof?.preferences.filterElevator ?? false;
    _braille = prof?.preferences.filterBrailleMenu ?? false;
    _guideDog = prof?.preferences.filterGuideDogFriendly ?? false;
  }

  String _labelForDisability(DisabilityType t) {
    switch (t) {
      case DisabilityType.none:
        return '해당 없음/기타';
      case DisabilityType.wheelchair:
        return '이동(휠체어) 장애';
      case DisabilityType.visual:
        return '시각 장애';
      case DisabilityType.hearing:
        return '청각 장애';
      case DisabilityType.cognitive:
        return '인지/지적 장애';
      case DisabilityType.other:
        return '기타';
    }
  }

  String _labelForSortKey(SortKey k) {
    switch (k) {
      case SortKey.personalized:
        return '맞춤 추천';
      case SortKey.rating:
        return '별점 높은 순';
      case SortKey.distance:
        return '거리 가까운 순';
      case SortKey.accessibility:
        return '접근성 점수 높은 순';
    }
  }

  List<SortKey> _optionsForIndex(int idx) {
    final used = {..._priority}..remove(_priority[idx]);
    return SortKey.values.where((k) => !used.contains(k)).toList();
  }

  Widget _priorityDropdown(int idx, String title) {
    final current = _priority[idx];
    final options = _optionsForIndex(idx);
    if (!options.contains(current)) {
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
          onChanged: (v) => setState(() => _priority[idx] = v!),
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
      final prefs = UserPreferences(
        sortPriorityOrder: List<SortKey>.from(_priority),
        filterWheelchairRamp: _ramp,
        filterAccessibleRestroom: _restroom,
        filterElevator: _elevator,
        filterBrailleMenu: _braille,
        filterGuideDogFriendly: _guideDog,
      );

      await context
          .read<UserProvider>()
          .markOnboardingComplete(prefs: prefs, disabilityType: _disabilityType);

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('저장 실패: 네트워크를 확인하세요.')),
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
          const Text('장애 유형 선택',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ...DisabilityType.values.map(
            (t) => RadioListTile<DisabilityType>(
              value: t,
              groupValue: _disabilityType,
              onChanged: (v) => setState(() => _disabilityType = v!),
              title: Text(_labelForDisability(t)),
            ),
          ),
          const Divider(height: 32),

          const Text('정렬 우선순위',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          _priorityDropdown(0, '1순위'),
          const SizedBox(height: 12),
          _priorityDropdown(1, '2순위'),
          const SizedBox(height: 12),
          _priorityDropdown(2, '3순위'),
          const Divider(height: 32),

          const Text('접근성 필터',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          SwitchListTile(
            value: _ramp,
            onChanged: (v) => setState(() => _ramp = v),
            title: const Text('경사로 있음'),
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
            title: const Text('점자 메뉴 있음'),
          ),
          SwitchListTile(
            value: _guideDog,
            onChanged: (v) => setState(() => _guideDog = v),
            title: const Text('안내견 동반 가능'),
          ),
          const SizedBox(height: 24),

          FilledButton.icon(
            icon: _saving
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check),
            label: Text(_saving ? '저장 중...' : '완료하고 시작하기'),
            onPressed: canSave ? _save : null,
          ),
          TextButton(
            onPressed: _saving
                ? null
                : () => Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false),
            child: const Text('건너뛰기'),
          ),
        ],
      ),
    );
  }
}


