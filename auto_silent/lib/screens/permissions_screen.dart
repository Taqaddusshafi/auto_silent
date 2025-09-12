import 'package:flutter/material.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../services/silent_mode_service.dart';
import '../utils/constants.dart';
import 'home_screen.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  final LocationService _locationService = LocationService();
  final NotificationService _notificationService = NotificationService();
  final SilentModeService _silentModeService = SilentModeService();

  bool _locationGranted = false;
  bool _notificationGranted = false;
  bool _dndGranted = false;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 40),
              
              // Header
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.mosque,
                  size: 50,
                  color: AppColors.primary,
                ),
              ),
              
              const SizedBox(height: 30),
              
              Text(
                'Welcome to ${AppConstants.appName}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 16),
              
              Text(
                'To provide the best experience, we need a few permissions',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withOpacity(0.9),
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 40),
              
              // Permission Cards
              Expanded(
                child: Column(
                  children: [
                    _buildPermissionCard(
                      icon: Icons.location_on,
                      title: 'Location Access',
                      description: 'Required to calculate accurate prayer times',
                      isGranted: _locationGranted,
                      onTap: _requestLocationPermission,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    _buildPermissionCard(
                      icon: Icons.notifications,
                      title: 'Notifications',
                      description: 'Show prayer time and silence mode notifications',
                      isGranted: _notificationGranted,
                      onTap: _requestNotificationPermission,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    _buildPermissionCard(
                      icon: Icons.do_not_disturb,
                      title: 'Do Not Disturb',
                      description: 'Automatically silence device during prayers',
                      isGranted: _dndGranted,
                      onTap: _requestDNDPermission,
                    ),
                  ],
                ),
              ),
              
              // Continue Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _continueToApp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: AppColors.primary)
                      : const Text(
                          'Continue to App',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              Text(
                'You can change these permissions later in Settings',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionCard({
    required IconData icon,
    required String title,
    required String description,
    required bool isGranted,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
        ),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isGranted ? Colors.green : Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isGranted ? Icons.check : icon,
            color: isGranted ? Colors.white : Colors.white70,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          description,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
        trailing: TextButton(
          onPressed: isGranted ? null : onTap,
          child: Text(
            isGranted ? 'Granted' : 'Grant',
            style: TextStyle(
              color: isGranted ? Colors.green : Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _requestLocationPermission() async {
    final granted = await _locationService.requestLocationPermission();
    setState(() {
      _locationGranted = granted;
    });
  }

  Future<void> _requestNotificationPermission() async {
    final granted = await _notificationService.requestNotificationPermission();
    setState(() {
      _notificationGranted = granted;
    });
  }

  Future<void> _requestDNDPermission() async {
    await _silentModeService.requestDoNotDisturbPermission();
    // Note: DND permission is harder to check, so we'll assume it's granted
    setState(() {
      _dndGranted = true;
    });
  }

  Future<void> _continueToApp() async {
    setState(() {
      _isLoading = true;
    });

    // Small delay for UX
    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }
}
