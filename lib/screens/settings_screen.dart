// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/user_provider.dart';
import '../models/user_profile.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameCtrl = TextEditingController();
  bool _saving = false;
  bool _initedFromProfile = false;

  // Profile fields
  DisabilityType _disabilityType = DisabilityType.none;
  late List<SortKey> _priority; // length 3
  bool _ramp = false, _restroom = false, _elevator = false, _braille = false, _guideDog = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 초기 1회: Provider의 profile로 폼 값 채우기
    if (_initedFromProfile) return;
    final p = context.watch<UserProvider>().profile;
    if (p == null) return;

    _nameCtrl.text = p.displayName ?? '';
    _disabilityType = p.disabilityType;

    final order = p.preferences.sortPriorityOrder;
    _priority = order.isNotEmpty
        ? List<SortKey>.from(order)
        : List<SortKey>.from(UserPreferences.defaults().sortPriorityOrder);

    _ramp     = p.preferences.filterWheelchairRamp;
    _restroom = p.preferences.filterAccessibleRestroom;
    _elevator = p.preferences.filterElevator;
    _braille  = p.preferences.filterBrailleMenu;
    _guideDog = p.preferences.filterGuideDogFriendly;

    _initedFromProfile = true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
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
    if (!options.contains(current)) options.insert(0, current);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        DropdownButtonFormField<SortKey>(
          value: current,
          items: options
              .map((k) => DropdownMenuItem(value: k, child: Text(_labelForSortKey(k))))
              .toList(),
          onChanged: (v) {
            if (v == null) return;
            setState(() => _priority[idx] = v);
          },
          decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final prov = context.read<UserProvider>();
    final profile = prov.profile;
    if (profile == null) return;

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

      final newDisplayName = _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim();

      final updated = profile.copyWith(
        displayName: newDisplayName,
        disabilityType: _disabilityType,
        preferences: prefs,
      );

      await prov.saveProfile(updated); // Firestore merge + live 업데이트

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('저장되었습니다.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('저장 중 오류가 발생했습니다.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _signOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('정말 로그아웃하시겠어요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('로그아웃')),
        ],
      ),
    );
    if (ok != true) return;

    await context.read<UserProvider>().signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  Future<void> _deleteAccount() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('계정 삭제'),
        content: const Text('계정을 영구 삭제합니다. 이 작업은 되돌릴 수 없습니다. 계속할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await context.read<UserProvider>().deleteAccount();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('계정 삭제에 실패했습니다. 최근 로그인 필요할 수 있어요.')));
    }
  }

  Widget _avatar(UserProfile p) {
    final letter = (p.displayName ?? p.email ?? 'U').trim();
    final initial = letter.isEmpty ? '?' : letter.characters.first.toUpperCase();
    if ((p.photoUrl ?? '').isNotEmpty) {
      return CircleAvatar(radius: 28, backgroundImage: NetworkImage(p.photoUrl!));
    }
    return CircleAvatar(radius: 28, child: Text(initial, style: const TextStyle(fontSize: 20)));
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<UserProvider>();
    final p = prov.profile;

    if (p == null || prov.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('마이페이지 & 설정')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- Account section ---
          Row(
            children: [
              _avatar(p),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  p.email ?? '익명 사용자',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (p.points > 0)
                Chip(label: Text('Points ${p.points}')),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: '표시 이름(닉네임)',
              hintText: '예: 준영',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 24),
          const Text('장애 유형', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...DisabilityType.values.map(
            (t) => RadioListTile<DisabilityType>(
              value: t,
              groupValue: _disabilityType,
              onChanged: (v) => setState(() => _disabilityType = v!),
              title: Text(_labelForDisability(t)),
            ),
          ),

          const SizedBox(height: 24),
          const Text('정렬 우선순위', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _priorityDropdown(0, '1순위'),
          const SizedBox(height: 12),
          _priorityDropdown(1, '2순위'),
          const SizedBox(height: 12),
          _priorityDropdown(2, '3순위'),

          const SizedBox(height: 24),
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
          FilledButton.icon(
            icon: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save),
            label: Text(_saving ? '저장 중...' : '저장'),
            onPressed: _saving ? null : _save,
          ),

          const SizedBox(height: 16),
          const Divider(height: 32),

          // --- Danger zone / Account ---
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('로그아웃'),
            subtitle: const Text('현재 계정에서 로그아웃합니다.'),
            trailing: OutlinedButton(onPressed: _signOut, child: const Text('로그아웃')),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('계정 삭제'),
            subtitle: const Text('계정을 영구 삭제합니다. 최근 로그인 재인증이 필요할 수 있어요.'),
            trailing: TextButton(
              onPressed: _deleteAccount,
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('삭제'),
            ),
          ),
        ],
      ),
    );
  }
}

