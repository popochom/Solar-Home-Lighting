/*
Solar Home Lighting App
This is an app designed to control a smart home solar system. 
It allows users to monitor the system, while also providing functions for
switching lights and checking security cameras.
*/

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

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

  static const appTitle = 'Solar Home Lighting Monitor';

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
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
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

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return LandingPage();
      case 1:
        return const PowerDataPage();
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
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  // Firebase-backed power values
  double _generation = 0.0;
  double _battery = 0.0;
  double _usage = 0.0;
  // Configurable maxima (from settings)
  double _panelMax = 1000.0;
  double _batteryMax = 100.0;

  StreamSubscription<DatabaseEvent>? _genSub;
  StreamSubscription<DatabaseEvent>? _batSub;
  StreamSubscription<DatabaseEvent>? _useSub;
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
                    infoCard(
                      title: 'Current Generation (W)',
                      child: SpeedometerPlaceholder(value: _generation, max: _panelMax, unit: 'W'),
                    ),

                    // Battery Capacity (percent)
                    infoCard(
                      title: 'Battery Capacity (Ah)',
                      // Firebase provides battery as a percentage; convert to Ah
                      child: SpeedometerPlaceholder(value: (_battery / 100.0) * _batteryMax, max: _batteryMax, unit: 'Ah'),
                    ),

                    // Power Usage (watts)
                    infoCard(
                      title: 'Power Usage (W)',
                      child: SpeedometerPlaceholder(value: _usage, max: _panelMax, unit: 'W'),
                    ),

                    // Weather
                    infoCard(
                      title: 'Weather',
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Use an icon as placeholder for storm clouds
                          Icon(Icons.cloud, size: 48, color: colorScheme.primary),
                          const SizedBox(height: 8),
                          Text('79°', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                          const SizedBox(height: 4),
                          Text('Partly Cloudy', style: TextStyle(fontSize: 14, color: colorScheme.onSurface)),
                        ],
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

// Simple circular "speedometer" placeholder widget
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
  const PowerDataPage({super.key});

  @override
  State<PowerDataPage> createState() => _PowerDataPageState();
}

class _PowerDataPageState extends State<PowerDataPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text('Power Data Page'),
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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text('Camera Recordings Page'),
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
              labelText: 'Panel spec (W)',
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

// Helper to scope all database access under solar_data/users/<uid>
DatabaseReference userRef() {
  final uid = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
  return FirebaseDatabase.instance.ref().child('solar_data').child('users').child(uid);
}