/*
Solar Home Lighting App
This is an app designed to control a smart home solar system. 
It allows users to monitor the system, while also providing functions for
switching lights and checking security cameras.
*/

import "package:flutter/material.dart";
import "package:firebase_core/firebase_core.dart";
import "package:firebase_database/firebase_database.dart";
import "package:firebase_auth/firebase_auth.dart";
import "dart:async";
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/*
App layout:
  Login Page:
    - email & password fields
    - login button
    - create account button

  Main page:
    - simplified view of power data (Battery Capacity, Current Wattage, etc.)
    - buttons (or side menu?) to open other menus
    - local weather data
  
  Power Data:
    - display detailed power data
    - Panel & Battery Temperature sensor data
    - Error/Breaker Trip notifications

  Light Controls:
    - Customizable array of switch buttons
    - Edit mode to add/remove/rename switches
    - Status of each switch (on/off)

  Camera Recordings:
    - view recent recording (thumbnail & timestamp)
    - download videos for watching on device.
      - in app video player?

  About:
    - Problem Statement
    - Brief description of app

  Settings:
    - Set location
    - dark/light mode
    - other user preferences

Helper functions:
  Firebase Access/Interaction:
    - Get information
    - Set information
    - download video data

  Power Info:
    - graph generation data, battery capacity, loads, etc
    -


*/

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(SolarHomeLighting());
}


//Main App
class SolarHomeLighting extends StatefulWidget {
  const SolarHomeLighting({super.key});

  static const appTitle = "Solar Home Lighting Monitor";

  @override
  State<SolarHomeLighting> createState() => _SolarHomeLightingState();
}

class _SolarHomeLightingState extends State<SolarHomeLighting> {
  ThemeMode _themeMode = ThemeMode.system;

  void _setDarkMode(bool enabled) {
    setState(() {
      _themeMode = enabled ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    final light = ThemeData(
      brightness: Brightness.light,
      primaryColor: const Color.fromARGB(255, 128, 0, 0),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color.fromARGB(255, 128, 0, 0),
        titleTextStyle: TextStyle(color: Colors.white, fontSize: 20),
        centerTitle: true,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(Colors.white),
        trackColor: WidgetStateProperty.all(Colors.grey),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color.fromARGB(255, 128, 0, 0),
        ),
      ),
    );

    final dark = ThemeData.dark().copyWith(
      primaryColor: const Color.fromARGB(255, 128, 0, 0),
      scaffoldBackgroundColor: const Color(0xFF121212),
      cardColor: const Color(0xFF1E1E1E),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color.fromARGB(255, 128, 0, 0),
        titleTextStyle: TextStyle(color: Colors.white, fontSize: 20),
        centerTitle: true,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(Colors.tealAccent),
        trackColor: WidgetStateProperty.all(Colors.teal),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color.fromARGB(255, 128, 0, 0),
        ),
      ),
    );

    return MaterialApp(
      title: SolarHomeLighting.appTitle,
      theme: light,
      darkTheme: dark,
      themeMode: _themeMode,
      // Gate the app behind authentication; AuthGate will show LoginPage
      // when not signed in and MyHomePage when signed in.
      home: AuthGate(themeMode: _themeMode, onThemeChanged: _setDarkMode),
    );
  }
}

// Authentication gate: shows LoginPage when not signed-in, otherwise the main app
class AuthGate extends StatelessWidget {
  final ThemeMode themeMode;
  final void Function(bool) onThemeChanged;

  const AuthGate({super.key, required this.themeMode, required this.onThemeChanged});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasData && snapshot.data != null) {
          // Signed in
          return MyHomePage(title: SolarHomeLighting.appTitle, themeMode: themeMode, onThemeChanged: onThemeChanged);
        }

        return const LoginPage();
      },
    );
  }
}

// Simple Login page using Firebase Auth (email/password)
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _loading = false;

  Future<void> _showMessage(String msg) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _signIn() async {
    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      // on success, AuthGate's stream will update and show the main app
    } on FirebaseAuthException catch (e) {
      await _showMessage(e.message ?? 'Sign-in failed');
    } catch (_) {
      await _showMessage('Sign-in failed');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _register() async {
    setState(() => _loading = true);
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // On successful account creation, import the default data template
      // into the new user's subtree: solar_data/users/<uid>
      final user = cred.user;
      if (user != null) {
        try {
          final uid = user.uid;
          final ref = FirebaseDatabase.instance.ref().child('solar_data').child('users').child(uid);
          await ref.set(_dataTemplate);
        } catch (e) {
          // If writing the template fails, still consider the account created,
          // but inform the user.
          await _showMessage('Account created but failed to initialize user data');
          if (mounted) setState(() => _loading = false);
          return;
        }
      }

      await _showMessage('Account created — signed in');
    } on FirebaseAuthException catch (e) {
      await _showMessage(e.message ?? 'Account creation failed');
    } catch (_) {
      await _showMessage('Account creation failed');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      await _showMessage('Enter your email to reset password');
      return;
    }

    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      await _showMessage('Password reset email sent');
    } on FirebaseAuthException catch (e) {
      await _showMessage(e.message ?? 'Failed to send reset email');
    } catch (_) {
      await _showMessage('Failed to send reset email');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Welcome', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _loading ? null : _signIn,
                  child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Log in'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _loading ? null : _register,
                  child: const Text('Create account'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _loading ? null : _resetPassword,
                  child: const Text('Forgot password?'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title, required this.themeMode, required this.onThemeChanged});

  final String title;
  final ThemeMode themeMode;
  final void Function(bool) onThemeChanged;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;
  final database = userRef();
  int? _requestedMetricIndex;
  int? _requestedIntervalIndex;

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return LandingPage(onNavigateToPage: (page, {int? metricIndex, int? intervalIndex}) {
          setState(() {
            _selectedIndex = page;
            _requestedMetricIndex = metricIndex;
            _requestedIntervalIndex = intervalIndex;
          });
        });
      case 1:
        return PowerDataPage(initialMetricIndex: _requestedMetricIndex, initialIntervalIndex: _requestedIntervalIndex);
      case 2:
        return const LightControlsPage();
      case 3:
        return const CameraRecordingsPage();
      case 4:
        return const AboutPage();
      case 5:
        return SettingsPage(themeMode: widget.themeMode, onThemeChanged: widget.onThemeChanged);
      default:
        return const LandingPage();
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: TextStyle(
            //fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          )
        ),
        centerTitle: true,
        backgroundColor: Color.fromARGB(255, 128, 0, 0),
        leading: Builder(
          builder: (context) {
            return IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            );
          },
        ),
      ),
  body: Center(child: _buildPage(_selectedIndex)),
      drawer: Drawer(
        child: Column(
          children: [
            // Header + scrollable list
            const DrawerHeader(
              decoration: BoxDecoration(color: Color.fromARGB(255, 128, 0, 0)),
              child: Text(
                'Solar \nHome \nLighting \nMonitor',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  ListTile(
                    leading: const Icon(Icons.home),
                    title: const Text('Home'),
                    selected: _selectedIndex == 0,
                    onTap: () {
                      _onItemTapped(0);
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.bolt),
                    title: const Text('Power Data'),
                    selected: _selectedIndex == 1,
                    onTap: () {
                      _onItemTapped(1);
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.lightbulb),
                    title: const Text('Light Controls'),
                    selected: _selectedIndex == 2,
                    onTap: () {
                      _onItemTapped(2);
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.videocam),
                    title: const Text('Recordings'),
                    selected: _selectedIndex == 3,
                    onTap: () {
                      _onItemTapped(3);
                      Navigator.pop(context);
                    },
                  ),
                  const Divider(
                    height: 20,
                    thickness: 2,
                    indent: 20,
                    endIndent: 20,
                    color: Colors.grey,
                  ),
                  ListTile(
                    leading: const Icon(Icons.info),
                    title: const Text('About'),
                    onTap: () {
                      _onItemTapped(4);
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.settings),
                    title: const Text('Settings'),
                    onTap: () {
                      _onItemTapped(5);
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),

            // Bottom sign-out button
            SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text('Sign out'),
                    onTap: () async {
                      try {
                        await FirebaseAuth.instance.signOut();
                      } catch (e) {
                        // ignore sign-out errors — auth state will update if successful
                      }
                      // Close the drawer
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

//Landing Page
class LandingPage extends StatefulWidget {
  final void Function(int page, {int? metricIndex, int? intervalIndex})? onNavigateToPage;

  const LandingPage({super.key, this.onNavigateToPage});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  // Firebase-backed power values
  double _generation = 0.0;
  double _battery = 0.0;
  double _usage = 0.0;
  double _batteryTemp = 0.0;
  // Configurable maxima (from settings)
  double _panelMax = 1000.0;
  double _batteryMax = 100.0;

  StreamSubscription<DatabaseEvent>? _genSub;
  StreamSubscription<DatabaseEvent>? _batSub;
  StreamSubscription<DatabaseEvent>? _useSub;
  StreamSubscription<DatabaseEvent>? _sensorSub;
  StreamSubscription<DatabaseEvent>? _panelMaxSub;
  StreamSubscription<DatabaseEvent>? _batteryMaxSub;

  @override
  void initState() {
    super.initState();
    _startPowerListeners();
  }

  void _startPowerListeners() {
    final db = userRef();

    _genSub = db.child('powerData').child('generation').onValue.listen((event) {
      final v = _parseFirebaseNumeric(event.snapshot.value);
      if (mounted) setState(() => _generation = v);
    }, onError: (_) {});

    _batSub = db.child('powerData').child('battery').onValue.listen((event) {
      final v = _parseFirebaseNumeric(event.snapshot.value);
      if (mounted) setState(() => _battery = v);
    }, onError: (_) {});

    _useSub = db.child('powerData').child('usage').onValue.listen((event) {
      final v = _parseFirebaseNumeric(event.snapshot.value);
      if (mounted) setState(() => _usage = v);
    }, onError: (_) {});

    // listen for configurable maxima in settings
    _panelMaxSub = db.child('settings').child('panelSpecW').onValue.listen((event) {
      final v = _parseFirebaseNumeric(event.snapshot.value);
      if (v > 0 && mounted) setState(() => _panelMax = v);
    }, onError: (_) {});

    _batteryMaxSub = db.child('settings').child('batteryCapacityMax').onValue.listen((event) {
      final v = _parseFirebaseNumeric(event.snapshot.value);
      if (v > 0 && mounted) setState(() => _batteryMax = v);
    }, onError: (_) {});

    // sensorData (battery temperature)
    _sensorSub = db.child('sensorData').onValue.listen((event) {
      try {
        final snap = event.snapshot.value;
        if (snap is Map && snap.containsKey('battery_temp')) {
          final v = snap['battery_temp'];
          final parsed = _parseFirebaseNumeric(v);
          if (mounted) setState(() => _batteryTemp = parsed);
        } else if (snap is Map && snap.containsKey('battery_Temp')) {
          final v = snap['battery_Temp'];
          final parsed = _parseFirebaseNumeric(v);
          if (mounted) setState(() => _batteryTemp = parsed);
        }
      } catch (_) {}
    }, onError: (_) {});
  }

  Future<void> _manualRefresh() async {
    try {
  final db = userRef();
  final genSnap = await db.child('powerData').child('generation').get();
  final batSnap = await db.child('powerData').child('battery').get();
  final useSnap = await db.child('powerData').child('usage').get();

      final gen = _parseFirebaseNumeric(genSnap.value);
      final bat = _parseFirebaseNumeric(batSnap.value);
      final use = _parseFirebaseNumeric(useSnap.value);

      if (mounted) {
        setState(() {
          _generation = gen;
          _battery = bat;
          _usage = use;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to refresh data from Firebase')));
      }
    }
  }

  double _parseFirebaseNumeric(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  @override
  void dispose() {
    _genSub?.cancel();
    _batSub?.cancel();
    _useSub?.cancel();
    _panelMaxSub?.cancel();
    _batteryMaxSub?.cancel();
    _sensorSub?.cancel();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    Widget infoCard({required Widget child, required String title}) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colorScheme.onSurface)),
              const SizedBox(height: 8),
              // Use Flexible with a loose fit so the child may size itself
              // without forcing overflow in tight cards (fixes small bottom
              // overflow in the Weather card).
              Flexible(fit: FlexFit.loose, child: child),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Stack(
          children: [
            // Grid of cards that also responds to taps to trigger a manual refresh
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _manualRefresh,
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  children: [
                    // Current Generation (watts)
                    GestureDetector(
                      onTap: () => widget.onNavigateToPage?.call(1, metricIndex: 0),
                      child: infoCard(
                        title: 'Current Generation (W)',
                        child: SpeedometerPlaceholder(value: _generation, max: _panelMax, unit: 'W'),
                      ),
                    ),

                    // Battery Capacity (percent)
                    GestureDetector(
                      onTap: () => widget.onNavigateToPage?.call(1, metricIndex: 1),
                      child: infoCard(
                        title: 'Battery Capacity (Ah)',
                        // Firebase provides battery as a percentage; convert to Ah
                        child: SpeedometerPlaceholder(value: (_battery / 100.0) * _batteryMax, max: _batteryMax, unit: 'Ah'),
                      ),
                    ),

                    // Power Usage (watts)
                    GestureDetector(
                      onTap: () => widget.onNavigateToPage?.call(1, metricIndex: 0),
                      child: infoCard(
                        title: 'Power Usage (W)',
                        child: SpeedometerPlaceholder(value: _usage, max: _panelMax, unit: 'W'),
                      ),
                    ),

                    // Battery Temperature (°C)
                    GestureDetector(
                      onTap: () => widget.onNavigateToPage?.call(1, metricIndex: 3),
                      child: infoCard(
                        title: 'Battery Temperature (°C)',
                        child: Center(
                          child: SpeedometerPlaceholder(value: _batteryTemp, max: 100, unit: '°C'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // small refresh button in the bottom-right of the landing area
            Positioned(
              bottom: 8,
              right: 8,
              child: Material(
                color: Colors.transparent,
                child: IconButton(
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh),
                  onPressed: _manualRefresh,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Simple circular "speedometer" widget
class SpeedometerPlaceholder extends StatelessWidget {
  final double value;
  final double max;
  final String unit;

  const SpeedometerPlaceholder({super.key, required this.value, required this.max, required this.unit});

  @override
  Widget build(BuildContext context) {
    final pct = (value / max).clamp(0.0, 1.0);
    final primary = Theme.of(context).colorScheme.primary;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return LayoutBuilder(builder: (context, constraints) {
      final size = constraints.biggest.shortestSide;
      return Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                value: pct,
                strokeWidth: 12,
                color: primary,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(value.toStringAsFixed(value < 10 ? 1 : 0), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: onSurface)),
                const SizedBox(height: 4),
                Text(unit, style: TextStyle(fontSize: 12)),
              ],
            ),
          ],
        ),
      );
    });
  }
}


//Power Data Page
class PowerDataPage extends StatefulWidget {
  final int? initialMetricIndex;
  final int? initialIntervalIndex;

  const PowerDataPage({super.key, this.initialMetricIndex, this.initialIntervalIndex});

  @override
  State<PowerDataPage> createState() => _PowerDataPageState();
}

class _PowerDataPageState extends State<PowerDataPage> {
  StreamSubscription<DatabaseEvent>? _readingsSub;
  Map<String, dynamic> _readings = {};

  // Metrics the user can choose from
  final List<Map<String, String>> _metrics = [
    {"label": "Power (W)", "key": "power", "unit": "W"},
    {"label": "Current (A)", "key": "current", "unit": "A"},
    {"label": "Voltage (V)", "key": "voltage", "unit": "V"},
    {"label": "Temperature (°C)", "key": "temperature", "unit": "°C"},
  ];
  int _metricIndex = 0;

  // Time interval options
  final List<Map<String, dynamic>> _intervals = [
    {"label": "30 mins", "dur": Duration(minutes: 30)},
    {"label": "1 hour", "dur": Duration(hours: 1)},
    {"label": "6 hours", "dur": Duration(hours: 6)},
    {"label": "24 hours", "dur": Duration(hours: 24)},
  ];
  int _intervalIndex = 2; // default 6 hours

  @override
  void initState() {
    super.initState();
    // initialize metric/interval from widget if provided
    if (widget.initialMetricIndex != null) _metricIndex = widget.initialMetricIndex!;
    if (widget.initialIntervalIndex != null) _intervalIndex = widget.initialIntervalIndex!;
    _subscribe();
  }

  void _subscribe() {
    _readingsSub?.cancel();
    _readingsSub = userRef().child('readings').onValue.listen((event) {
      final v = event.snapshot.value;
      if (v is Map) {
        setState(() => _readings = Map<String, dynamic>.from(v));
      } else {
        setState(() => _readings = {});
      }
    }, onError: (_) {
      setState(() => _readings = {});
    });
  }

  @override
  void dispose() {
    _readingsSub?.cancel();
    super.dispose();
  }

  // Build the key used by the DB: MMDDYYYYhhmm (UTC)
  String _keyForUtc(DateTime dt) {
    final t = dt.toUtc();
    final mm = t.month.toString().padLeft(2, '0');
    final dd = t.day.toString().padLeft(2, '0');
    final yyyy = t.year.toString();
    final hh = t.hour.toString().padLeft(2, '0');
    final mi = t.minute.toString().padLeft(2, '0');
    return '$mm$dd$yyyy$hh$mi';
  }

  double _extract(dynamic entry, String key) {
    if (entry == null) return 0.0;
    if (entry is num) return entry.toDouble();
    if (entry is String) return double.tryParse(entry) ?? 0.0;
    if (entry is Map) {
      final v = entry[key];
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
    }
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final metricKey = _metrics[_metricIndex]['key']!;
    final unit = _metrics[_metricIndex]['unit']!;
    final dur = _intervals[_intervalIndex]['dur'] as Duration;

    final end = DateTime.now().toUtc();
    final start = end.subtract(dur);
    final step = Duration(minutes: 5);

    // Floor start to nearest 5 minutes
    DateTime t = DateTime.utc(start.year, start.month, start.day, start.hour, (start.minute ~/ 5) * 5);
    if (t.isBefore(start)) t = t.add(step);

    final times = <DateTime>[];
    while (t.isBefore(end) || t.isAtSameMomentAs(end)) {
      times.add(t);
      t = t.add(step);
    }

    final spots = <FlSpot>[];
    for (var i = 0; i < times.length; i++) {
      final key = _keyForUtc(times[i]);
      final entry = _readings[key];
      final y = _extract(entry, metricKey);
      final x = times[i].difference(times.first).inMinutes.toDouble();
      spots.add(FlSpot(x, y));
    }

    final totalX = times.isNotEmpty ? times.last.difference(times.first).inMinutes.toDouble() : dur.inMinutes.toDouble();

    // Compute highest datapoint within last 24 hours for this metric
    double max24 = 0.0;
    final start24 = end.subtract(const Duration(hours: 24));
    DateTime tt = DateTime.utc(start24.year, start24.month, start24.day, start24.hour, (start24.minute ~/ 5) * 5);
    if (tt.isBefore(start24)) tt = tt.add(step);
    while (tt.isBefore(end) || tt.isAtSameMomentAs(end)) {
      final k = _keyForUtc(tt);
      final e = _readings[k];
      final v = _extract(e, metricKey);
      if (v > max24) max24 = v;
      tt = tt.add(step);
    }
    final yMax = (max24 <= 0) ? 1.0 : max24 * 1.5;

    // Constrain the visual chart area to a 4:3 landscape rectangle and not full-screen.
    final screenW = MediaQuery.of(context).size.width;
    final maxW = math.min(screenW * 0.95, 1000.0);

    return Scaffold(
      appBar: AppBar(title: const Text('Power Data')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButton<int>(
                    value: _metricIndex,
                    isExpanded: true,
                    items: List.generate(_metrics.length, (i) => DropdownMenuItem(value: i, child: Text(_metrics[i]['label']!))),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _metricIndex = v);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 160,
                  child: DropdownButton<int>(
                    value: _intervalIndex,
                    isExpanded: true,
                    items: List.generate(_intervals.length, (i) => DropdownMenuItem(value: i, child: Text(_intervals[i]['label'] as String))),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _intervalIndex = v);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Centered landscape card with aspect ratio 4:3
            Center(
              child: SizedBox(
                width: maxW,
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('${_metrics[_metricIndex]['label']} — last ${_intervals[_intervalIndex]['label']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Expanded(
                            child: times.isEmpty
                                ? const Center(child: Text('No data range'))
                                : LineChart(
                                    LineChartData(
                                      minX: 0,
                                      maxX: totalX,
                                      minY: 0,
                                      maxY: yMax,
                                      lineBarsData: [
                                        LineChartBarData(
                                          spots: spots,
                                          isCurved: true,
                                          dotData: FlDotData(show: true),
                                          belowBarData: BarAreaData(show: false),
                                          color: Theme.of(context).colorScheme.primary,
                                          barWidth: 2,
                                        ),
                                      ],
                                      gridData: FlGridData(show: true),
                                      titlesData: FlTitlesData(
                                        bottomTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            reservedSize: 40,
                                            interval: (totalX / 6).clamp(1, totalX),
                                            getTitlesWidget: (value, meta) {
                                              final dt = times.first.add(Duration(minutes: value.toInt()));
                                              final h = dt.hour.toString().padLeft(2, '0');
                                              final m = dt.minute.toString().padLeft(2, '0');
                                              return Padding(
                                                padding: const EdgeInsets.only(top: 8.0),
                                                child: Text('$h:$m', style: const TextStyle(fontSize: 10)),
                                              );
                                            },
                                          ),
                                        ),
                                        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 48)),
                                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      ),
                                      borderData: FlBorderData(show: true),
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 8),
                          Text('Values shown in $unit', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


//Light Controls Page
class LightControlsPage extends StatefulWidget {
  const LightControlsPage({super.key});

  @override
  State<LightControlsPage> createState() => _LightControlsPageState();
}

class LightingControl {
  String name;
  bool isOn;

  LightingControl({required this.name, this.isOn = false});
}

class _LightControlsPageState extends State<LightControlsPage> {
  final lightingControlsRef = userRef().child("lightingControls");

  // Example initial controls; you can replace or load these from Firebase.
  final List<LightingControl> controls = [
    LightingControl(name: 'Porch', isOn: false),
    LightingControl(name: 'Living Room', isOn: false),
    LightingControl(name: 'Kitchen', isOn: false),
  ];

  bool _isEditing = false;

  void _toggleControl(int index, bool value) {
    setState(() {
      controls[index].isOn = value;
    });

    // Write the new state to Firebase under lightingControls/<controlName>
    try {
      lightingControlsRef.child(controls[index].name).set(value);
    } catch (e) {
      // If Firebase isn't available, we still update local UI.
      // In production, handle errors or show a SnackBar.
    }
  }

  void _addControl() {
    setState(() {
      final newName = 'Light ${controls.length + 1}';
      controls.add(LightingControl(name: newName, isOn: false));
    });
  }

  Future<void> _renameControl(int index) async {
    final oldName = controls[index].name;
    final controller = TextEditingController(text: oldName);
    final result = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Control'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Rename')),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && result != oldName) {
      setState(() {
        controls[index].name = result;
      });

      // Update Firebase: set new child value and remove old child
      try {
        final value = controls[index].isOn;
        await lightingControlsRef.child(result).set(value);
        await lightingControlsRef.child(oldName).remove();
      } catch (e) {
        // handle errors as needed
      }
    }
  }

  Future<void> _removeControl(int index) async {
    final name = controls[index].name;
    final confirm = await showDialog<bool?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Control'),
        content: Text('Are you sure you want to remove "$name"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        controls.removeAt(index);
      });
      try {
        await lightingControlsRef.child(name).remove();
      } catch (e) {
        // handle errors as needed
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: controls.length,
              itemBuilder: (context, index) {
                final c = controls[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.name,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              c.isOn ? 'Status: ON' : 'Status: OFF',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                        // When editing, show edit/delete icons; otherwise show the switch
                        _isEditing
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () => _renameControl(index),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete),
                                    onPressed: () => _removeControl(index),
                                  ),
                                ],
                              )
                            : Switch(
                                value: c.isOn,
                                onChanged: (value) => _toggleControl(index, value),
                              ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: () => setState(() => _isEditing = !_isEditing),
                icon: Icon(_isEditing ? Icons.check : Icons.edit),
                label: Text(_isEditing ? 'Done' : 'Edit Controls'),
                style: ElevatedButton.styleFrom(
                  // Ensure label and icon are white regardless of theme
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _addControl,
                icon: const Icon(Icons.add),
                label: const Text('Add Control'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


//Camera Recordings Page
class CameraRecordingsPage extends StatefulWidget {
  const CameraRecordingsPage({super.key});

  @override
  State<CameraRecordingsPage> createState() => _CameraRecordingsPageState();
}

class _CameraRecordingsPageState extends State<CameraRecordingsPage> {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  List<Reference> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadList();
  }

  Future<void> _loadList() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final ref = _storage.ref().child('recordings');
      final listResult = await ref.listAll();
      setState(() => _items = List<Reference>.from(listResult.items));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to list recordings')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _ensurePermissions() async {
    // request relevant permissions for saving to external storage.
    try {
      bool granted = false;
      if (Platform.isAndroid) {
        final storage = await Permission.storage.request();
        // On Android 11+, requesting manageExternalStorage may be required
        final manage = await Permission.manageExternalStorage.request();
        granted = storage.isGranted || manage.isGranted;
      } else if (Platform.isIOS) {
        final photos = await Permission.photos.request();
        granted = photos.isGranted;
      } else {
        // For other platforms, attempt storage permission
        final storage = await Permission.storage.request();
        granted = storage.isGranted;
      }

      if (granted) return true;

      // Not granted — prompt user to open app settings to grant permission
      if (!mounted) return false;
      final open = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Permission required'),
          content: const Text('The app needs storage permissions to save recordings to your device. Open app settings to grant permission?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Open settings')),
          ],
        ),
      );

      if (open == true) {
        await openAppSettings();
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _downloadAndSave(Reference ref) async {
    if (!await _ensurePermissions()) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Storage/photos permission required')));
      return;
    }

    final fileName = ref.name;
    try {
      final tempDir = await getTemporaryDirectory();
      final localFile = File('${tempDir.path}/$fileName');

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Downloading...')));

      final task = ref.writeToFile(localFile);
      await task;

      // Try to copy to the standard DCIM/Camera folder on Android. On modern
      // Android versions this may require MANAGE_EXTERNAL_STORAGE or scoped
      // storage handling; we'll attempt a best-effort copy and show the path.
      if (Platform.isAndroid) {
        final targetDir = Directory('/storage/emulated/0/DCIM/Camera');
        try {
          if (!await targetDir.exists()) await targetDir.create(recursive: true);
          final dest = File('${targetDir.path}/$fileName');
          await localFile.copy(dest.path);
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved to ${dest.path}')));
        } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to copy file to DCIM/Camera')));
        }
      } else {
        // For iOS and other platforms, leave the file in the temp dir and inform the user.
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Downloaded to ${localFile.path}')));
      }

      // cleanup temp file where possible
      try { if (await localFile.exists()) await localFile.delete(); } catch (_) {}
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Download failed')));
    }
  }

  Widget _buildItemTile(Reference ref) {
    return FutureBuilder<FullMetadata>(
      future: ref.getMetadata(),
      builder: (context, snap) {
  final sizeBytes = snap.data?.size ?? 0;
  final subtitle = snap.hasData ? '${(sizeBytes / 1024 / 1024).toStringAsFixed(2)} MB' : null;
        return ListTile(
          leading: const Icon(Icons.videocam),
          title: Text(ref.name),
          subtitle: subtitle != null ? Text(subtitle) : null,
          trailing: IconButton(icon: const Icon(Icons.download_rounded), onPressed: () => _downloadAndSave(ref)),
          onTap: () => _downloadAndSave(ref),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recordings'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadList, tooltip: 'Refresh'),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('No recordings found'),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(onPressed: _loadList, icon: const Icon(Icons.refresh), label: const Text('Refresh')),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) => Card(child: _buildItemTile(_items[index])),
                ),
    );
  }
}


//About Page (stateless)
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyMedium?.color ?? theme.colorScheme.onSurface;
    final headingStyle = TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor);
    final bodyStyle = TextStyle(fontSize: 16, height: 1.4, color: textColor);
    final labelStyle = TextStyle(fontWeight: FontWeight.bold, color: textColor);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text('About Us', style: headingStyle),
            const SizedBox(height: 16),
            Text.rich(
              TextSpan(
                style: bodyStyle,
                children: [
                  TextSpan(text: 'Problem statement:\n', style: labelStyle),
                  const TextSpan(text: 'Traditional Home lighting systems often lack remote monitoring and control capabilities, making it difficult for users to manage their energy consumption effectively.'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text.rich(
              TextSpan(
                style: bodyStyle,
                children: [
                  TextSpan(text: 'Brief description:\n', style: labelStyle),
                  const TextSpan(text: 'This app serves as a user-friendly interface for monitoring and controlling your Solar Home Lighting system. It provides real-time data on power usage, battery status, and allows for easy control of connected lighting devices. Users can customize their lighting controls, view camera recordings, and adjust settings to suit their preferences.'),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

//Settings Page
class SettingsPage extends StatefulWidget {
  final ThemeMode themeMode;
  final void Function(bool) onThemeChanged;

  const SettingsPage({super.key, required this.themeMode, required this.onThemeChanged});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int _nightPref = 0;
  late TextEditingController _panelController;
  late TextEditingController _batteryController;

  @override
  void initState() {
    super.initState();
    _loadNightPref();
    _panelController = TextEditingController();
    _batteryController = TextEditingController();
    _loadSpecs();
  }
  @override
  void dispose() {
    _panelController.dispose();
    _batteryController.dispose();
    super.dispose();
  }

  Future<void> _loadSpecs() async {
    try {
      final db = userRef().child('settings');
      final panelSnap = await db.child('panelSpecW').get();
      if (panelSnap.exists) {
        final v = panelSnap.value;
        if (v != null) {
          final parsed = v is num ? v.toDouble() : double.tryParse(v.toString());
          if (parsed != null) _panelController.text = parsed.toString();
        }
      }

  final batSnap = await db.child('batteryCapacityMax').get();
      if (batSnap.exists) {
        final v = batSnap.value;
        if (v != null) {
          final parsed = v is num ? v.toDouble() : double.tryParse(v.toString());
          if (parsed != null) _batteryController.text = parsed.toString();
        }
      }
    } catch (e) {
      // ignore load errors
    }
  }

  Future<void> _loadNightPref() async {
    try {
      final snap = await userRef().child('settings').child('nightLightPref').get();
      if (snap.exists) {
        final val = snap.value;
        if (val is int) {
          setState(() => _nightPref = val);
        } else if (val is String) {
          final parsed = int.tryParse(val);
          if (parsed != null) setState(() => _nightPref = parsed);
        }
      }
    } catch (e) {
      // ignore load errors; keep default
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Dark mode tile moved to bottom of settings for easier access after other preferences.
          // Additional settings can be added here
          const SizedBox(height: 16),
          const SizedBox(height: 8),
          const Text('Solar Panel Specifications', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _panelController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Total Panel Wattage (W)',
              hintText: 'e.g. 1000.0',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _batteryController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Battery capacity (Ah)',
              hintText: 'e.g. 200.0',
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () async {
              final panelText = _panelController.text.trim();
              final batText = _batteryController.text.trim();
              final panelVal = double.tryParse(panelText);
              final batVal = double.tryParse(batText);
              if (panelVal == null || panelVal <= 0) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid panel spec')));
                return;
              }
              if (batVal == null || batVal <= 0) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid battery capacity')));
                return;
              }

              try {
                final settingsRef = userRef().child('settings');
                await settingsRef.child('panelSpecW').set(panelVal);
                await settingsRef.child('batteryCapacityMax').set(batVal);
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Specifications saved')));
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save specifications')));
              }
            },
            child: const Text('Save Specifications'),
          ),
          const Text('Night lighting mode', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            DropdownButton<int>(
              value: _nightPref,
              items: const [
                DropdownMenuItem(value: 0, child: Text('Off')),
                DropdownMenuItem(value: 1, child: Text('Motion')),
                DropdownMenuItem(value: 2, child: Text('Human Activity')),
              ],
              onChanged: (v) async {
                if (v == null) return;
                try {
                    await userRef().child('settings').child('nightLightPref').set(v);
                  setState(() => _nightPref = v);
                } catch (e) {
                  if(context.mounted){
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save night lighting preference')));
                  }
                }
              },
            ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Dark mode'),
            subtitle: const Text('Toggle between light and dark themes'),
            value: widget.themeMode == ThemeMode.dark,
            onChanged: (value) async {
              // Update remote setting in Firebase
              try {
                final settingsRef = userRef().child('settings');
                await settingsRef.child('darkMode').set(value);
              } catch (e) {
                if(context.mounted){
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to save setting to Firebase')),
                  );
                }
              }

              // Update local app theme
              widget.onThemeChanged(value);
              setState(() {});
            },
            secondary: const Icon(Icons.brightness_6),
          ),
        ],
      ),
    );
  }
}

//database access under solar_data/users/<uid>
DatabaseReference userRef() {
  final uid = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
  return FirebaseDatabase.instance.ref().child('solar_data').child('users').child(uid);
}

// Default user data template imported for new accounts.
const Map<String, dynamic> _dataTemplate = {
  "lightingControls": {
    "Kitchen": false,
    "Living Room": false,
    "Patio": false,
    "Porch": false,
  },
  "powerData": {
    "battery": 65,
    "generation": 77,
    "usage": 69,
  },
  "readings": {
    "111120251000": {"current": 0.56, "power": 10.0, "temperature": 18.0, "voltage": 18.0, "timestamp_human": "2025-11-11T10:00:00Z"},
    "111120251005": {"current": 0.69, "power": 12.5, "temperature": 18.4, "voltage": 18.0, "timestamp_human": "2025-11-11T10:05:00Z"},
    "111120251010": {"current": 0.83, "power": 15.0, "temperature": 18.8, "voltage": 18.0, "timestamp_human": "2025-11-11T10:10:00Z"},
    "111120251015": {"current": 0.97, "power": 17.5, "temperature": 19.2, "voltage": 18.0, "timestamp_human": "2025-11-11T10:15:00Z"},
    "111120251020": {"current": 1.11, "power": 20.0, "temperature": 19.6, "voltage": 18.0, "timestamp_human": "2025-11-11T10:20:00Z"},
    "111120251025": {"current": 1.25, "power": 22.5, "temperature": 20.0, "voltage": 18.0, "timestamp_human": "2025-11-11T10:25:00Z"},
    "111120251030": {"current": 1.39, "power": 25.0, "temperature": 20.4, "voltage": 18.0, "timestamp_human": "2025-11-11T10:30:00Z"},
    "111120251035": {"current": 1.53, "power": 27.5, "temperature": 20.8, "voltage": 18.0, "timestamp_human": "2025-11-11T10:35:00Z"},
    "111120251040": {"current": 1.67, "power": 30.0, "temperature": 21.2, "voltage": 18.0, "timestamp_human": "2025-11-11T10:40:00Z"},
    "111120251045": {"current": 1.81, "power": 32.5, "temperature": 21.6, "voltage": 18.0, "timestamp_human": "2025-11-11T10:45:00Z"},
    "111120251050": {"current": 1.94, "power": 35.0, "temperature": 22.0, "voltage": 18.0, "timestamp_human": "2025-11-11T10:50:00Z"},
    "111120251055": {"current": 2.08, "power": 37.5, "temperature": 22.4, "voltage": 18.0, "timestamp_human": "2025-11-11T10:55:00Z"},
    "111120251100": {"current": 2.22, "power": 40.0, "temperature": 22.8, "voltage": 18.0, "timestamp_human": "2025-11-11T11:00:00Z"},
    "111120251105": {"current": 2.36, "power": 42.5, "temperature": 23.2, "voltage": 18.0, "timestamp_human": "2025-11-11T11:05:00Z"},
    "111120251110": {"current": 2.50, "power": 45.0, "temperature": 23.6, "voltage": 18.0, "timestamp_human": "2025-11-11T11:10:00Z"},
    "111120251115": {"current": 2.64, "power": 47.5, "temperature": 24.0, "voltage": 18.0, "timestamp_human": "2025-11-11T11:15:00Z"},
    "111120251120": {"current": 2.78, "power": 50.0, "temperature": 24.4, "voltage": 18.0, "timestamp_human": "2025-11-11T11:20:00Z"},
    "111120251125": {"current": 2.92, "power": 52.5, "temperature": 24.8, "voltage": 18.0, "timestamp_human": "2025-11-11T11:25:00Z"},
    "111120251130": {"current": 3.06, "power": 55.0, "temperature": 25.2, "voltage": 18.0, "timestamp_human": "2025-11-11T11:30:00Z"},
    "111120251135": {"current": 3.19, "power": 57.5, "temperature": 25.6, "voltage": 18.0, "timestamp_human": "2025-11-11T11:35:00Z"},
    "111120251140": {"current": 3.33, "power": 60.0, "temperature": 26.0, "voltage": 18.0, "timestamp_human": "2025-11-11T11:40:00Z"},
    "111120251145": {"current": 3.47, "power": 62.5, "temperature": 26.4, "voltage": 18.0, "timestamp_human": "2025-11-11T11:45:00Z"},
    "111120251150": {"current": 3.61, "power": 65.0, "temperature": 26.8, "voltage": 18.0, "timestamp_human": "2025-11-11T11:50:00Z"},
    "111120251155": {"current": 3.75, "power": 67.5, "temperature": 27.2, "voltage": 18.0, "timestamp_human": "2025-11-11T11:55:00Z"},
    "111120251200": {"current": 3.89, "power": 70.0, "temperature": 27.6, "voltage": 18.0, "timestamp_human": "2025-11-11T12:00:00Z"},
    "111120251205": {"current": 4.03, "power": 72.5, "temperature": 28.0, "voltage": 18.0, "timestamp_human": "2025-11-11T12:05:00Z"},
    "111120251210": {"current": 4.17, "power": 75.0, "temperature": 28.4, "voltage": 18.0, "timestamp_human": "2025-11-11T12:10:00Z"},
    "111120251215": {"current": 4.31, "power": 77.5, "temperature": 28.8, "voltage": 18.0, "timestamp_human": "2025-11-11T12:15:00Z"},
    "111120251220": {"current": 4.44, "power": 80.0, "temperature": 29.2, "voltage": 18.0, "timestamp_human": "2025-11-11T12:20:00Z"},
    "111120251225": {"current": 4.58, "power": 82.5, "temperature": 29.6, "voltage": 18.0, "timestamp_human": "2025-11-11T12:25:00Z"},
    "111120251230": {"current": 4.72, "power": 85.0, "temperature": 30.0, "voltage": 18.0, "timestamp_human": "2025-11-11T12:30:00Z"},
    "111120251235": {"current": 4.86, "power": 87.5, "temperature": 30.4, "voltage": 18.0, "timestamp_human": "2025-11-11T12:35:00Z"},
    "111120251300": {"current": 5.00, "power": 90.0, "temperature": 30.8, "voltage": 18.0, "timestamp_human": "2025-11-11T13:00:00Z"},
    "111120251305": {"current": 5.14, "power": 92.5, "temperature": 31.2, "voltage": 18.0, "timestamp_human": "2025-11-11T13:05:00Z"},
    "111120251310": {"current": 5.28, "power": 95.0, "temperature": 31.6, "voltage": 18.0, "timestamp_human": "2025-11-11T13:10:00Z"},
    "111120251315": {"current": 5.42, "power": 97.5, "temperature": 32.0, "voltage": 18.0, "timestamp_human": "2025-11-11T13:15:00Z"},
    "111120251320": {"current": 5.56, "power": 100.0, "temperature": 33.0, "voltage": 18.0, "timestamp_human": "2025-11-11T13:20:00Z"},
    "111120251325": {"current": 5.43, "power": 97.8, "temperature": 32.9, "voltage": 18.0, "timestamp_human": "2025-11-11T13:25:00Z"},
    "111120251330": {"current": 5.31, "power": 95.6, "temperature": 32.8, "voltage": 18.0, "timestamp_human": "2025-11-11T13:30:00Z"},
    "111120251335": {"current": 5.19, "power": 93.3, "temperature": 32.7, "voltage": 18.0, "timestamp_human": "2025-11-11T13:35:00Z"},
    "111120251340": {"current": 5.06, "power": 91.1, "temperature": 32.6, "voltage": 18.0, "timestamp_human": "2025-11-11T13:40:00Z"},
    "111120251345": {"current": 4.94, "power": 88.9, "temperature": 32.5, "voltage": 18.0, "timestamp_human": "2025-11-11T13:45:00Z"},
    "111120251350": {"current": 4.82, "power": 86.7, "temperature": 32.4, "voltage": 18.0, "timestamp_human": "2025-11-11T13:50:00Z"},
    "111120251355": {"current": 4.69, "power": 84.4, "temperature": 32.3, "voltage": 18.0, "timestamp_human": "2025-11-11T13:55:00Z"},
    "111120251400": {"current": 4.57, "power": 82.2, "temperature": 32.2, "voltage": 18.0, "timestamp_human": "2025-11-11T14:00:00Z"},
    "111120251405": {"current": 4.44, "power": 80.0, "temperature": 32.1, "voltage": 18.0, "timestamp_human": "2025-11-11T14:05:00Z"},
    "111120251410": {"current": 4.32, "power": 77.8, "temperature": 32.0, "voltage": 18.0, "timestamp_human": "2025-11-11T14:10:00Z"},
    "111120251415": {"current": 4.20, "power": 75.6, "temperature": 31.9, "voltage": 18.0, "timestamp_human": "2025-11-11T14:15:00Z"},
    "111120251420": {"current": 4.07, "power": 73.3, "temperature": 31.8, "voltage": 18.0, "timestamp_human": "2025-11-11T14:20:00Z"},
    "111120251425": {"current": 3.95, "power": 71.1, "temperature": 31.7, "voltage": 18.0, "timestamp_human": "2025-11-11T14:25:00Z"},
    "111120251430": {"current": 3.83, "power": 68.9, "temperature": 31.6, "voltage": 18.0, "timestamp_human": "2025-11-11T14:30:00Z"},
    "111120251435": {"current": 3.70, "power": 66.7, "temperature": 31.5, "voltage": 18.0, "timestamp_human": "2025-11-11T14:35:00Z"},
    "111120251440": {"current": 3.58, "power": 64.4, "temperature": 31.4, "voltage": 18.0, "timestamp_human": "2025-11-11T14:40:00Z"},
    "111120251445": {"current": 3.46, "power": 62.2, "temperature": 31.3, "voltage": 18.0, "timestamp_human": "2025-11-11T14:45:00Z"},
    "111120251450": {"current": 3.33, "power": 60.0, "temperature": 31.2, "voltage": 18.0, "timestamp_human": "2025-11-11T14:50:00Z"},
    "111120251455": {"current": 3.21, "power": 57.8, "temperature": 31.1, "voltage": 18.0, "timestamp_human": "2025-11-11T14:55:00Z"},
    "111120251500": {"current": 3.09, "power": 55.6, "temperature": 31.0, "voltage": 18.0, "timestamp_human": "2025-11-11T15:00:00Z"},
    "111120251505": {"current": 2.96, "power": 53.3, "temperature": 30.9, "voltage": 18.0, "timestamp_human": "2025-11-11T15:05:00Z"},
    "111120251510": {"current": 2.84, "power": 51.1, "temperature": 30.8, "voltage": 18.0, "timestamp_human": "2025-11-11T15:10:00Z"},
    "111120251515": {"current": 2.72, "power": 48.9, "temperature": 30.7, "voltage": 18.0, "timestamp_human": "2025-11-11T15:15:00Z"},
    "111120251520": {"current": 2.59, "power": 46.7, "temperature": 30.6, "voltage": 18.0, "timestamp_human": "2025-11-11T15:20:00Z"},
    "111120251525": {"current": 2.47, "power": 44.4, "temperature": 30.5, "voltage": 18.0, "timestamp_human": "2025-11-11T15:25:00Z"},
    "111120251530": {"current": 2.35, "power": 42.2, "temperature": 30.4, "voltage": 18.0, "timestamp_human": "2025-11-11T15:30:00Z"},
    "111120251535": {"current": 2.22, "power": 40.0, "temperature": 30.3, "voltage": 18.0, "timestamp_human": "2025-11-11T15:35:00Z"},
    "111120251540": {"current": 2.10, "power": 37.8, "temperature": 30.2, "voltage": 18.0, "timestamp_human": "2025-11-11T15:40:00Z"},
    "111120251545": {"current": 1.98, "power": 35.6, "temperature": 30.1, "voltage": 18.0, "timestamp_human": "2025-11-11T15:45:00Z"},
    "111120251550": {"current": 1.85, "power": 33.3, "temperature": 30.0, "voltage": 18.0, "timestamp_human": "2025-11-11T15:50:00Z"},
    "111120251555": {"current": 1.73, "power": 31.1, "temperature": 29.9, "voltage": 18.0, "timestamp_human": "2025-11-11T15:55:00Z"},
  },
  "sensorData": {
    "battery_temp": 70,
    "motion": false,
  },
  "settings": {
    "batteryCapacityMax": 24,
    "darkMode": true,
    "nightLightPref": 0,
    "panelSpecW": 100,
  },
};