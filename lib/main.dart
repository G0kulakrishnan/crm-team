import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/attendance_screen.dart';

void main() {
  runApp(const CrmCallLoggerApp());
}

class CrmCallLoggerApp extends StatefulWidget {
  const CrmCallLoggerApp({super.key});

  @override
  State<CrmCallLoggerApp> createState() => _CrmCallLoggerAppState();
}

class _CrmCallLoggerAppState extends State<CrmCallLoggerApp> {
  final ApiService _apiService = ApiService();
  bool _loading = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _apiService.loadConfig();
    setState(() {
      _isLoggedIn = _apiService.isConfigured;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'T2G CRM Team',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF16A34A),
        fontFamily: 'Roboto',
      ),
      home: _loading
          ? const Scaffold(
              backgroundColor: Color(0xFFF8FAFC),
              body: Center(child: CircularProgressIndicator(color: Color(0xFF16A34A))),
            )
          : _isLoggedIn
              ? _MainShell(
                  apiService: _apiService,
                  onLogout: () => setState(() => _isLoggedIn = false),
                )
              : LoginScreen(
                  apiService: _apiService,
                  onLoggedIn: () => setState(() => _isLoggedIn = true),
                ),
    );
  }
}

/// Shell with bottom navigation: Call Logs | Attendance
class _MainShell extends StatefulWidget {
  final ApiService apiService;
  final VoidCallback onLogout;

  const _MainShell({required this.apiService, required this.onLogout});

  @override
  State<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<_MainShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomeScreen(
            apiService: widget.apiService,
            onLogout: widget.onLogout,
          ),
          AttendanceScreen(apiService: widget.apiService),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        height: 64,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFF16A34A).withAlpha(30),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.phone_outlined),
            selectedIcon: Icon(Icons.phone, color: Color(0xFF16A34A)),
            label: 'Call Logs',
          ),
          NavigationDestination(
            icon: Icon(Icons.access_time_outlined),
            selectedIcon: Icon(Icons.access_time_filled, color: Color(0xFF16A34A)),
            label: 'Attendance',
          ),
        ],
      ),
    );
  }
}
