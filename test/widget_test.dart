import 'package:flutter_test/flutter_test.dart';
import 'package:skribbl_clone/create_room_screen.dart';
import 'package:skribbl_clone/home_screen.dart';
import 'package:skribbl_clone/join_room_screen.dart';
import 'package:skribbl_clone/main.dart';
import 'package:skribbl_clone/services/sound_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skribbl_clone/services/server_config_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Home Screen direct launch smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp(home: HomeScreen()));

    expect(find.text('Create/Join Room to play...'), findsOneWidget);
    expect(find.text('Create'), findsOneWidget);
    expect(find.text('Join'), findsOneWidget);
  });

  testWidgets('Create Room Screen Arcade Pop BGM smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp(home: CreateRoomScreen()));

    expect(find.text('Create Room'), findsWidgets);
    expect(find.text('Arcade Pop BGM'), findsOneWidget);
  });

  testWidgets('Join Room Screen Arcade Pop BGM smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp(home: JoinRoomScreen()));

    expect(find.text('Join Room'), findsWidgets);
    expect(find.text('Arcade Pop BGM'), findsOneWidget);
  });

  testWidgets('Splash Screen launch smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Draw. Guess. Win.'), findsOneWidget);
    expect(find.text('SKRIBBL'), findsWidgets);
  });

  test('SoundService mute test', () {
    final sound = SoundService.instance;
    expect(sound.isMuted, isFalse);

    sound.toggleMute();
    expect(sound.isMuted, isTrue);

    sound.setMuted(false);
    expect(sound.isMuted, isFalse);
  });

  test('ServerConfigService initial and update test', () async {
    final serverConfig = ServerConfigService.instance;
    await serverConfig.init();
    expect(serverConfig.serverUrl.isNotEmpty, isTrue);

    await serverConfig.setServerUrl('192.168.0.112:3000');
    expect(serverConfig.serverUrl, 'http://192.168.0.112:3000');
  });
}
