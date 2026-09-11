import 'package:flutter/material.dart';
import '../services/google_drive_sync_service.dart';
import '../services/local_storage_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isSignedIn = false;
  bool _isSyncing = false;
  String _lastBackupDate = 'Never';

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final signedIn = await GoogleDriveSyncService.isSignedIn();
    final lastBackup = await LocalStorageService.getLastBackupDate();
    setState(() {
      _isSignedIn = signedIn;
      _lastBackupDate = lastBackup != null
          ? lastBackup.toLocal().toString().split('.')[0]
          : 'Never';
    });
  }

  Future<void> _handleSignInOut() async {
    setState(() => _isSyncing = true);
    if (_isSignedIn) {
      await GoogleDriveSyncService.signOut();
    } else {
      await GoogleDriveSyncService.signIn();
    }
    await _loadStatus();
    setState(() => _isSyncing = false);
  }

  Future<void> _handleBackup() async {
    setState(() => _isSyncing = true);
    final success = await GoogleDriveSyncService.backupData();
    await _loadStatus();
    setState(() => _isSyncing = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Backup successful!' : 'Backup failed.'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _handleRestore() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Data'),
        content: const Text(
          'Are you sure you want to restore from Google Drive? This will overwrite all your current local data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSyncing = true);
    final success = await GoogleDriveSyncService.restoreData();
    await _loadStatus();
    setState(() => _isSyncing = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Restore successful! Restart app to see changes.'
                : 'Restore failed or no backup found.',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings & Cloud Sync')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Google Drive Backup',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF9AD9C5),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Safely backup your highway directory and travel history to a hidden folder in your Google Drive. It will automatically sync daily.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 24),
          ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            tileColor: const Color(0xFF1B201F),
            leading: const Icon(
              Icons.cloud_circle_rounded,
              size: 36,
              color: Colors.blueAccent,
            ),
            title: Text(_isSignedIn ? 'Signed in to Google' : 'Not signed in'),
            subtitle: Text('Last Backup: $_lastBackupDate'),
            trailing: _isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : TextButton(
                    onPressed: _handleSignInOut,
                    child: Text(_isSignedIn ? 'Sign Out' : 'Sign In'),
                  ),
          ),
          if (_isSignedIn) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSyncing ? null : _handleBackup,
                    icon: const Icon(Icons.upload_rounded),
                    label: const Text('Backup Now'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B2522),
                      foregroundColor: const Color(0xFF9AD9C5),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSyncing ? null : _handleRestore,
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Restore Data'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF251B1B),
                      foregroundColor: const Color(0xFFD99A9A),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
