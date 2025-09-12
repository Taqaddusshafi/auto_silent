import 'package:flutter/material.dart';
import 'dart:async';
import '../models/prayer_time.dart';
import '../services/prayer_time_service.dart';
import '../services/silent_mode_service.dart';
import '../widgets/prayer_time_card.dart';
import '../utils/date_time_utils.dart';

class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({super.key});

  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen> {
  final PrayerTimeService _prayerService = PrayerTimeService();
  final SilentModeService _silentModeService = SilentModeService();
  final TextEditingController _customTimeController = TextEditingController();
  
  List<PrayerTime> _prayerTimes = [];
  bool _isLoading = true;
  bool _isTestingDND = false;
  DateTime _selectedDate = DateTime.now();
  
  // Custom prayer time test variables
  bool _isCustomTestActive = false;
  DateTime? _customTestTime;
  Timer? _customTestTimer;
  Timer? _customCheckTimer;
  TimeOfDay _selectedCustomTime = TimeOfDay.now();

  @override
  void initState() {
    super.initState();
    _loadPrayerTimes();
    _updateCustomTimeController();
  }

  @override
  void dispose() {
    _customTestTimer?.cancel();
    _customCheckTimer?.cancel();
    _customTimeController.dispose();
    super.dispose();
  }

  void _updateCustomTimeController() {
    final now = TimeOfDay.now();
    final testTime = TimeOfDay(hour: now.hour, minute: now.minute + 2);
    _selectedCustomTime = testTime;
    _customTimeController.text = '${testTime.hour.toString().padLeft(2, '0')}:${testTime.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _loadPrayerTimes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prayerTimes = await _prayerService.getPrayerTimesForDate(_selectedDate);
      setState(() {
        _prayerTimes = prayerTimes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading prayer times: $e')),
      );
    }
  }

  // Test DND functionality (existing method)
  Future<void> _testDNDFunctionality() async {
    setState(() {
      _isTestingDND = true;
    });

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.science, color: Colors.blue.shade600),
              const SizedBox(width: 8),
              const Text('Testing Manual DND'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Testing Do Not Disturb functionality...'),
              const SizedBox(height: 8),
              Text(
                'This will enable silent mode for 30 seconds',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );

      final permissions = await _silentModeService.checkAllPermissions();
      
      if (permissions.isEmpty || permissions['dnd'] != true) {
        Navigator.of(context).pop();
        await _showPermissionRequiredDialog();
        return;
      }

      final enableResult = await _silentModeService.enableSilentMode();
      
      if (enableResult) {
        Navigator.of(context).pop();
        await _showManualTestSuccessDialog();
      } else {
        Navigator.of(context).pop();
        await _showTestFailedDialog();
      }
    } catch (e) {
      Navigator.of(context).pop();
      await _showTestErrorDialog(e.toString());
    } finally {
      setState(() {
        _isTestingDND = false;
      });
    }
  }

  // Custom Prayer Time Test
  Future<void> _testCustomPrayerTime() async {
    if (_isCustomTestActive) {
      _cancelCustomTest();
      return;
    }

    // Parse custom time
    final customTime = _parseCustomTime();
    if (customTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid time (HH:MM)'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if time is in the future
    final now = DateTime.now();
    var testDateTime = DateTime(now.year, now.month, now.day, customTime.hour, customTime.minute);
    
    if (testDateTime.isBefore(now)) {
      testDateTime = testDateTime.add(const Duration(days: 1));
    }

    final timeDifference = testDateTime.difference(now);
    if (timeDifference.inMinutes > 60) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a time within the next hour for testing'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isCustomTestActive = true;
      _customTestTime = testDateTime;
    });

    _showCustomTestDialog(testDateTime);
    _startCustomTestTimers(testDateTime);
  }

  DateTime? _parseCustomTime() {
    try {
      final timeStr = _customTimeController.text.trim();
      final parts = timeStr.split(':');
      if (parts.length != 2) return null;
      
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      
      if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
      
      return DateTime(0, 0, 0, hour, minute);
    } catch (e) {
      return null;
    }
  }

  void _showCustomTestDialog(DateTime testTime) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.schedule, color: Colors.green.shade600),
                const SizedBox(width: 8),
                const Text('Custom Prayer Time Test'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.access_alarm,
                  color: Colors.green.shade600,
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Testing custom prayer time auto-silence',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Test prayer time: ${DateTimeUtils.formatTime(testTime)}',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),
                StreamBuilder<int>(
                  stream: Stream.periodic(const Duration(seconds: 1))
                      .map((_) => testTime.difference(DateTime.now()).inSeconds)
                      .takeWhile((seconds) => seconds > -10),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data! > 0) {
                      final remaining = Duration(seconds: snapshot.data!);
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Prayer time in:',
                              style: TextStyle(color: Colors.green.shade700),
                            ),
                            Text(
                              DateTimeUtils.formatDuration(remaining),
                              style: TextStyle(
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      );
                    } else {
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.volume_off, color: Colors.orange.shade700),
                            const SizedBox(width: 8),
                            Text(
                              'Prayer time reached!',
                              style: TextStyle(
                                color: Colors.orange.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _cancelCustomTest();
                  Navigator.of(context).pop();
                },
                child: const Text('Cancel Test'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _startCustomTestTimers(DateTime testTime) {
    final delay = testTime.difference(DateTime.now());
    
    // Main timer for when prayer time is reached
    _customTestTimer = Timer(delay, () async {
      await _simulateCustomPrayerTime();
      
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      _showCustomTestResult();
    });

    // Periodic checker (every 5 seconds)
    _customCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!_isCustomTestActive || _customTestTime == null) {
        timer.cancel();
        return;
      }
      
      if (DateTime.now().isAfter(_customTestTime!)) {
        timer.cancel();
        _simulateCustomPrayerTime();
        
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        
        _showCustomTestResult();
      }
    });
  }

  Future<void> _simulateCustomPrayerTime() async {
    try {
      print('=== Custom Prayer Time Test ===');
      print('Custom prayer time reached: ${_customTestTime}');
      
      final customPrayer = PrayerTime(
        name: 'Custom Test Prayer',
        time: _customTestTime!,
        isEnabled: true,
      );
      
      final success = await _silentModeService.enableSilentModeForPrayer(customPrayer);
      print('Custom prayer time auto-silence result: $success');
      
      setState(() {
        _isCustomTestActive = false;
      });
      
    } catch (e) {
      print('Custom prayer time test error: $e');
      setState(() {
        _isCustomTestActive = false;
      });
    }
  }

  void _showCustomTestResult() {
    final wasSuccessful = _silentModeService.isSilenceModeActive;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              wasSuccessful ? Icons.check_circle : Icons.error,
              color: wasSuccessful ? Colors.green.shade600 : Colors.red.shade600,
            ),
            const SizedBox(width: 8),
            Text(wasSuccessful ? 'Custom Test Successful!' : 'Custom Test Failed'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              wasSuccessful ? Icons.volume_off : Icons.volume_up,
              color: wasSuccessful ? Colors.green : Colors.red,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              wasSuccessful 
                  ? 'Custom prayer time auto-silence worked perfectly! Your device was automatically silenced at ${DateTimeUtils.formatTime(_customTestTime!)}'
                  : 'Custom prayer time auto-silence failed. The system may need additional permissions or device-specific settings.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          if (wasSuccessful)
            TextButton(
              onPressed: () async {
                await _silentModeService.disableSilentMode();
                Navigator.of(context).pop();
                setState(() {});
              },
              child: const Text('Disable Silent Mode'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _cancelCustomTest() {
    _customTestTimer?.cancel();
    _customCheckTimer?.cancel();
    setState(() {
      _isCustomTestActive = false;
      _customTestTime = null;
    });
  }

  Future<void> _selectCustomTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedCustomTime,
    );

    if (picked != null) {
      setState(() {
        _selectedCustomTime = picked;
        _customTimeController.text = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  // Existing dialog methods (shortened for brevity)
  Future<void> _showPermissionRequiredDialog() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange.shade600),
            const SizedBox(width: 8),
            const Text('Permission Required'),
          ],
        ),
        content: const Text('DND permission is not granted. Please grant the permission to test the functionality.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _silentModeService.requestDoNotDisturbPermission();
            },
            child: const Text('Grant Permission'),
          ),
        ],
      ),
    );
  }

  Future<void> _showManualTestSuccessDialog() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade600),
            const SizedBox(width: 8),
            const Text('Manual Test Successful!'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.volume_off, color: Colors.green, size: 48),
            SizedBox(height: 16),
            Text('Silent mode is now active!', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Your device should be silent now. Test will auto-disable in 30 seconds.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await _silentModeService.disableSilentMode();
              Navigator.of(context).pop();
              setState(() {});
            },
            child: const Text('Disable Now'),
          ),
        ],
      ),
    );

    Future.delayed(const Duration(seconds: 30), () async {
      await _silentModeService.disableSilentMode();
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      if (mounted) setState(() {});
    });
  }

  Future<void> _showTestFailedDialog() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [Icon(Icons.error, color: Colors.red.shade600), const SizedBox(width: 8), const Text('Test Failed')],
        ),
        content: const Text('Failed to enable silent mode. Check permissions and device settings.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
        ],
      ),
    );
  }

  Future<void> _showTestErrorDialog(String error) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [Icon(Icons.error, color: Colors.red.shade600), const SizedBox(width: 8), const Text('Test Error')],
        ),
        content: Text('An error occurred during testing:\n\n$error'),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
      ),
    );
  }

  Widget _buildTroubleshootItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(Icons.circle, size: 6, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prayer Times'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _selectDate,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildTestCard(),
          _buildCustomTestCard(),
          _buildDateSelector(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadPrayerTimes,
                    child: _buildPrayerTimesList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Card(
        color: Colors.blue.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.science, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'Test Manual Silent Mode',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (_silentModeService.isSilenceModeActive)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.volume_off, size: 14, color: Colors.orange.shade700),
                          const SizedBox(width: 4),
                          Text('ACTIVE', style: TextStyle(color: Colors.orange.shade700, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Test immediate DND functionality to verify permissions.',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isTestingDND ? null : _testDNDFunctionality,
                      icon: _isTestingDND 
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.volume_off, size: 18),
                      label: Text(_isTestingDND ? 'Testing...' : 'Test Manual DND'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  if (_silentModeService.isSilenceModeActive) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await _silentModeService.disableSilentMode();
                          setState(() {});
                        },
                        icon: const Icon(Icons.volume_up, size: 18),
                        label: const Text('Disable'),
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomTestCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Card(
        color: Colors.green.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.schedule, color: Colors.green.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'Test Custom Prayer Time',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Set a custom time to test automatic prayer time silence.',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _customTimeController,
                      decoration: InputDecoration(
                        labelText: 'Test Time (24-hour format)',
                        hintText: 'HH:MM',
                        prefixIcon: const Icon(Icons.access_time),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.schedule),
                          onPressed: _selectCustomTime,
                        ),
                      ),
                      keyboardType: TextInputType.datetime,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isCustomTestActive ? _cancelCustomTest : _testCustomPrayerTime,
                    icon: Icon(_isCustomTestActive ? Icons.cancel : Icons.play_arrow),
                    label: Text(_isCustomTestActive ? 'Cancel' : 'Start Test'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isCustomTestActive ? Colors.red.shade600 : Colors.green.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                    ),
                  ),
                ],
              ),
              if (_isCustomTestActive && _customTestTime != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade300),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.timer, color: Colors.orange.shade700, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Custom prayer test active',
                            style: TextStyle(color: Colors.orange.shade700, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      StreamBuilder<int>(
                        stream: Stream.periodic(const Duration(seconds: 1))
                            .map((_) => _customTestTime!.difference(DateTime.now()).inSeconds)
                            .takeWhile((seconds) => seconds > -60),
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            final seconds = snapshot.data!;
                            if (seconds > 0) {
                              final duration = Duration(seconds: seconds);
                              return Text(
                                'Prayer time in: ${duration.inMinutes}:${(seconds % 60).toString().padLeft(2, '0')}',
                                style: TextStyle(color: Colors.orange.shade700, fontSize: 12),
                              );
                            } else {
                              return Text(
                                'Prayer time reached! Testing auto-silence...',
                                style: TextStyle(color: Colors.red.shade700, fontSize: 12, fontWeight: FontWeight.bold),
                              );
                            }
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  setState(() {
                    _selectedDate = _selectedDate.subtract(const Duration(days: 1));
                  });
                  _loadPrayerTimes();
                },
              ),
              GestureDetector(
                onTap: _selectDate,
                child: Text(
                  DateTimeUtils.formatDate(_selectedDate),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  setState(() {
                    _selectedDate = _selectedDate.add(const Duration(days: 1));
                  });
                  _loadPrayerTimes();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrayerTimesList() {
    if (_prayerTimes.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.access_time, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No prayer times available', style: TextStyle(fontSize: 18, color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _prayerTimes.length,
      itemBuilder: (context, index) {
        final prayer = _prayerTimes[index];
        return PrayerTimeCard(
          prayer: prayer,
          isActive: false,
          isNext: false,
          showToggle: false,
        );
      },
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadPrayerTimes();
    }
  }
}
