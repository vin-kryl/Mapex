import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mapex/model/node.dart';
import 'package:mapex/settings/app_settings.dart';
import 'package:mapex/settings/settings_store.dart';

void main() {
  test('defaults: history cap 200', () {
    expect(AppSettings.defaults.historyCap, 200);
  });

  test('round trip', () {
    final s = AppSettings.defaults.copyWith(
      theme: ThemeChoice.dark,
      historyCap: 50,
      defaultNodeType: NodeType.decision,
      fontScale: 1.2,
    );
    final back = AppSettings.fromJson(s.toJson());
    expect(back.toJson(), s.toJson());
  });

  test('bad or missing values fall back to defaults', () {
    final s = AppSettings.fromJson({
      'theme': 'purple',
      'historyCap': -4,
      'fontScale': 'big',
      'decisionPromptDelayMinutes': -1,
    });
    expect(s.theme, AppSettings.defaults.theme);
    expect(s.historyCap, AppSettings.historyCapRange.min);
    expect(s.fontScale, AppSettings.defaults.fontScale);
    expect(
      s.decisionPromptDelayMinutes,
      AppSettings.defaults.decisionPromptDelayMinutes,
    );
    expect(
      AppSettings.fromJson('nonsense').toJson(),
      AppSettings.defaults.toJson(),
    );
  });

  test('store saves and loads, and survives a broken file', () async {
    final tmp = await Directory.systemTemp.createTemp('mapex_settings_');
    addTearDown(() => tmp.delete(recursive: true));
    final store = SettingsStore(tmp);
    expect((await store.load()).historyCap, 200);
    await store.save(AppSettings.defaults.copyWith(historyCap: 7));
    expect((await store.load()).historyCap, 7);
    File('${tmp.path}/settings.json').writeAsStringSync('{broken');
    expect((await store.load()).historyCap, 200);
  });

  test('look: colours are checked, radius clamped', () {
    final s = AppSettings.fromJson({
      'accentColor': '#2563eb',
      'nodeColors': ['#ABCDEF', 'red', 12, '#123456'],
      'doneColor': 'green',
      'cornerRadius': 99,
    });
    expect(s.accentColor, '#2563EB');
    expect(s.nodeColors, ['#ABCDEF', '#123456']);
    expect(s.doneColor, AppSettings.defaults.doneColor);
    expect(s.cornerRadius, AppSettings.cornerRadiusRange.max);
    expect(
      AppSettings.fromJson({'nodeColors': []}).nodeColors,
      AppSettings.defaults.nodeColors,
    );
    final back = AppSettings.fromJson(s.toJson());
    expect(back.nodeColors, s.nodeColors);
    expect(s.copyWith(accentColor: () => null).accentColor, isNull);
  });
}
