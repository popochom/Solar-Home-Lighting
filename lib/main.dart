/*
Solar Home Lighting App
This is an app designed to control a smart home solar system. 
It allows users to monitor the system, while also providing functions for
switching lights and checking security cameras.
*/

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

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
      home: MyHomePage(
        title: SolarHomeLighting.appTitle,
        themeMode: _themeMode,
        onThemeChanged: _setDarkMode,
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
  final database = FirebaseDatabase.instance.ref();

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return const LandingPage();
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
        // Add a ListView to the drawer. This ensures the user can scroll
        // through the options in the drawer if there isn't enough vertical
        // space to fit everything.
        child: ListView(
          // Important: Remove any padding from the ListView.
          padding: EdgeInsets.zero,
          children: [
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
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Home'),
              selected: _selectedIndex == 0,
              onTap: () {
                // Update the state of the app
                _onItemTapped(0);
                // Then close the drawer
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.bolt),
              title: const Text('Power Data'),
              selected: _selectedIndex == 1,
              onTap: () {
                // Update the state of the app
                _onItemTapped(1);
                // Then close the drawer
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.lightbulb),
              title: const Text('Light Controls'),
              selected: _selectedIndex == 2,
              onTap: () {
                // Update the state of the app
                _onItemTapped(2);
                // Then close the drawer
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text('Recordings'),
              selected: _selectedIndex == 3,
              onTap: () {
                // Update the state of the app
                _onItemTapped(3);
                // Then close the drawer
                Navigator.pop(context);
              },
            ),
            Divider(
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
                // Update the state of the app
                _onItemTapped(4);
                // Then close the drawer
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                // Update the state of the app
                _onItemTapped(5);
                // Then close the drawer
                Navigator.pop(context);
              },
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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text('Landing Page'),
      ),
    );
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
  final lightingControlsRef = FirebaseDatabase.instance.ref().child("lightingControls");

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
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _addControl,
                icon: const Icon(Icons.add),
                label: const Text('Add Control'),
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

  @override
  void initState() {
    super.initState();
    _loadNightPref();
  }

  Future<void> _loadNightPref() async {
    try {
      final snap = await FirebaseDatabase.instance.ref().child('settings/nightLightPref').get();
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
    final isDark = widget.themeMode == ThemeMode.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          SwitchListTile(
            title: const Text('Dark mode'),
            subtitle: const Text('Toggle between light and dark themes'),
            value: isDark,
            onChanged: (value) async {
              // Update remote setting in Firebase
              try {
                final settingsRef = FirebaseDatabase.instance.ref().child('settings');
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
          // Additional settings can be added here
          const SizedBox(height: 16),
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
                  await FirebaseDatabase.instance.ref().child('settings').child('nightLightPref').set(v);
                  setState(() => _nightPref = v);
                } catch (e) {
                  if(context.mounted){
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save night lighting preference')));
                  }
                }
              },
            ),
        ],
      ),
    );
  }
}