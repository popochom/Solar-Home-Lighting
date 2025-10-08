/*
Solar Home Lighting App
This is an app designed to control a smart home solar system. 
It allows users to monitor the system, while also providing functions for
switching lights and checking security cameras.
*/

import 'package:flutter/material.dart';

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

void main() {
  runApp(SolarHomeLighting());
}


//Main App
class SolarHomeLighting extends StatelessWidget {
  const SolarHomeLighting({super.key});

  static const appTitle = 'Solar Home Lighting Monitor';

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: appTitle,
      home: MyHomePage(title: appTitle),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;

  static const List<Widget> _widgetOptions = <Widget>[
    LandingPage(),
    PowerDataPage(),
    LightControlsPage(),
    CameraRecordingsPage(),
    AboutPage(),
    SettingsPage(),
  ];

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
      body: Center(child: _widgetOptions[_selectedIndex]),
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

class _LightControlsPageState extends State<LightControlsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text('Light Controls Page'),
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
    return Scaffold(
      body: Center(
        child: Text('About Page'),
      ),
    );
  }
}

//Settings Page
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text('Settings Page'),
      ),
    );
  }
}