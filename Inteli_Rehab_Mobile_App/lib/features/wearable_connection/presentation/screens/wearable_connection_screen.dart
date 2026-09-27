import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../sensor_calibration/presentation/screens/sensor_calibration_screen.dart';

class WearableConnectionScreen extends StatefulWidget {
  final bool isEmbedded;

  const WearableConnectionScreen({super.key, this.isEmbedded = false});

  @override
  State<WearableConnectionScreen> createState() => _WearableConnectionScreenState();
}

class _WearableConnectionScreenState extends State<WearableConnectionScreen> with SingleTickerProviderStateMixin {
  bool _isScanning = false;
  String? _connectedDeviceId = 'INTELI-ARM-01';
  final int _batteryLevel = 88;
  late AnimationController _pulseController;

  final List<Map<String, dynamic>> _devices = [
    {
      'id': 'INTELI-ARM-01',
      'name': 'Inteli-Wearable Arm V2',
      'mac': 'EC:62:60:9B:41:A2',
      'rssi': -58,
      'battery': 88,
      'isPaired': true,
      'type': 'IMU + EMG Sensor',
    },
    {
      'id': 'INTELI-EMG-02',
      'name': 'Inteli-Rehab EMG Patch',
      'mac': '24:0A:C4:81:72:3E',
      'rssi': -74,
      'battery': 62,
      'isPaired': false,
      'type': 'Muscle Surface EMG',
    },
    {
      'id': 'ESP32-MPU6050',
      'name': 'ESP32 Wearable Prototype',
      'mac': 'AC:67:B2:3F:19:5D',
      'rssi': -82,
      'battery': 95,
      'isPaired': false,
      'type': 'IMU Motion Tracker',
    },
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _toggleScan() {
    setState(() => _isScanning = !_isScanning);
    if (_isScanning) {
      Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _isScanning = false);
      });
    }
  }

  void _connectDevice(String id) {
    setState(() {
      _connectedDeviceId = id;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Connected to $id'),
        backgroundColor: AppTheme.primaryTeal,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _disconnectDevice() {
    setState(() {
      _connectedDeviceId = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sensor disconnected'),
        backgroundColor: AppTheme.slate600,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundWhite,
      appBar: AppBar(
        title: const Text('Wearable Device'),
        automaticallyImplyLeading: !widget.isEmbedded,
        actions: [
          IconButton(
            icon: Icon(_isScanning ? Icons.stop_rounded : Icons.refresh_rounded),
            tooltip: _isScanning ? 'Stop Scan' : 'Scan for Devices',
            onPressed: _toggleScan,
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Connected Device Hero Banner ───────────────────────────────────
            _buildConnectedDeviceCard(),
            const SizedBox(height: 20),

            // ── Bluetooth Hardware Health Checklist ────────────────────────────
            _buildHardwareChecklist(),
            const SizedBox(height: 24),

            // ── Available Nearby Devices Header ────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Nearby Rehabilitation Sensors',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.slate800),
                ),
                if (_isScanning)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryTeal),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Device List ────────────────────────────────────────────────────
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _devices.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final dev = _devices[index];
                final isConnected = _connectedDeviceId == dev['id'];
                return _buildDeviceTile(dev, isConnected);
              },
            ),
            const SizedBox(height: 24),

            // ── Calibration Shortcut Action ────────────────────────────────────
            if (_connectedDeviceId != null) ...[
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primaryTeal, AppTheme.navyMid],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryTeal.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SensorCalibrationScreen()),
                    );
                  },
                  icon: const Icon(Icons.tune_rounded, color: Colors.white),
                  label: const Text(
                    'Calibrate Sensor for Session',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConnectedDeviceCard() {
    if (_connectedDeviceId == null) {
      return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.slate200),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.amberLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.bluetooth_searching_rounded, color: AppTheme.amber, size: 36),
            ),
            const SizedBox(height: 14),
            const Text(
              'No Wearable Connected',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppTheme.slate800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Turn on your Inteli-Rehab sensor arm band and tap Scan to pair with your mobile device.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: AppTheme.slate500, height: 1.4),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _toggleScan,
              icon: Icon(_isScanning ? Icons.stop : Icons.search_rounded),
              label: Text(_isScanning ? 'Scanning...' : 'Scan for Sensor'),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.navy, AppTheme.navyMid],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppTheme.navy.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.tealBright.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: AppTheme.tealBright, size: 13),
                    SizedBox(width: 5),
                    Text(
                      'ACTIVE & STREAMING',
                      style: TextStyle(color: AppTheme.tealBright, fontSize: 10.5, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.battery_5_bar_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    '$_batteryLevel%',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Inteli-Wearable Arm V2',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          const Text(
            'MAC: EC:62:60:9B:41:A2 • Firmware v1.4.2',
            style: TextStyle(color: Colors.white70, fontSize: 11.5),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStreamMetricChip(Icons.rotate_90_degrees_cw_rounded, 'IMU 6-DOF', '50 Hz Stream'),
              const SizedBox(width: 10),
              _buildStreamMetricChip(Icons.show_chart_rounded, 'EMG Channel', '100 Hz Live'),
              const SizedBox(width: 10),
              _buildStreamMetricChip(Icons.wifi_tethering_rounded, 'Latency', '8 ms'),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _disconnectDevice,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white38),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Disconnect', style: TextStyle(fontSize: 13)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SensorCalibrationScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.tealBright,
                    foregroundColor: AppTheme.navy,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Calibrate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStreamMetricChip(IconData icon, String title, String val) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppTheme.tealBright, size: 12),
                const SizedBox(width: 4),
                Text(title, style: const TextStyle(color: Colors.white70, fontSize: 10)),
              ],
            ),
            const SizedBox(height: 3),
            Text(val, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildHardwareChecklist() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.slate200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatusIcon(Icons.bluetooth_rounded, 'Bluetooth', true),
          Container(width: 1, height: 30, color: AppTheme.slate200),
          _buildStatusIcon(Icons.location_on_outlined, 'Location', true),
          Container(width: 1, height: 30, color: AppTheme.slate200),
          _buildStatusIcon(Icons.battery_charging_full_rounded, 'Power Mode', true),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(IconData icon, String label, bool active) {
    return Row(
      children: [
        Icon(icon, color: active ? AppTheme.green : AppTheme.slate400, size: 18),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active ? AppTheme.slate800 : AppTheme.slate500,
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceTile(Map<String, dynamic> dev, bool isConnected) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isConnected ? AppTheme.primaryTeal : AppTheme.slate200,
          width: isConnected ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isConnected ? AppTheme.tealLight : AppTheme.tealSoftBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.developer_board_rounded,
              color: isConnected ? AppTheme.primaryTeal : AppTheme.slate600,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dev['name'] as String,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppTheme.slate800),
                ),
                const SizedBox(height: 2),
                Text(
                  '${dev['type']} • RSSI: ${dev['rssi']} dBm',
                  style: const TextStyle(fontSize: 11, color: AppTheme.slate500),
                ),
              ],
            ),
          ),
          if (isConnected)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.greenLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Connected',
                style: TextStyle(color: AppTheme.green, fontWeight: FontWeight.bold, fontSize: 11.5),
              ),
            )
          else
            OutlinedButton(
              onPressed: () => _connectDevice(dev['id'] as String),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Pair', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }
}
