import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

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
              ? HomeScreen(
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
