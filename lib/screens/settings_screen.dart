import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/app_theme.dart';
import '../services/notification_service.dart';
import '../providers/theme_notifier.dart';
import '../providers/wallet_state.dart';
import '../services/affirmation_service.dart';
import '../services/error_logger.dart';
import '../providers/settings_notifier.dart';
import '../services/storage_service.dart';
import 'error_logs_screen.dart';
import 'notification_debug_screen.dart';
import 'release_notes_screen.dart';

/// Settings: name, 4 themes, haptic, filter All/Favorites, favorites list, wallet, error logs link.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameController = TextEditingController();
  final StorageService _storage = StorageService();
  final NotificationService _notif = NotificationService();
  bool _haptic = true;
  bool _notificationsEnabled = false;
  bool _morningEnabled = false;
  String _morningTime = '09:00';
  bool _eveningEnabled = false;
  String _eveningTime = '20:00';
  bool _notificationPermissionGranted = true;
  bool _notificationLoading = false;
  String _startScreen = 'main';
  bool _showOnChainAnalytics = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final name = await _storage.getName();
    final haptic = await _storage.getHapticEnabled();
    final notifEnabled = await _storage.getNotificationsEnabled();
    final morningEnabled = await _storage.getMorningNotificationEnabled();
    final morningTime = await _storage.getMorningNotificationTime();
    final eveningEnabled = await _storage.getEveningNotificationEnabled();
    final eveningTime = await _storage.getEveningNotificationTime();
    final hasPermission = await _notif.hasPermission();
    final startScreen = await _storage.getStartScreen();
    final showOnChain = await _storage.getShowOnChainAnalytics();
    if (mounted) {
      _nameController.text = name;
      setState(() {
        _haptic = haptic;
        _notificationsEnabled = notifEnabled;
        _morningEnabled = morningEnabled;
        _morningTime = morningTime;
        _eveningEnabled = eveningEnabled;
        _eveningTime = eveningTime;
        _notificationPermissionGranted = hasPermission;
        _startScreen = startScreen;
        _showOnChainAnalytics = showOnChain;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveName(String value) async {
    await _storage.setName(value.isEmpty ? 'Friend' : value);
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    );
  }

  Widget _buildAboutSection(AppTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Daily Rabbit Confirmation',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Material(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () async {
              try {
                await launchUrl(
                  Uri.parse('https://dailyrabbitconfirmation.netlify.app/'),
                  mode: LaunchMode.externalApplication,
                );
              } catch (_) {}
            },
            borderRadius: BorderRadius.circular(12),
            child: ListTile(
              leading: Icon(Icons.language, color: theme.accentColor, size: 24),
              title: Text(
                'Visit Website',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  color: Colors.white,
                ),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white54),
            ),
          ),
        ),
      ],
    );
  }

  String _formatTimeForDisplay(String hhmm) {
    final parts = hhmm.split(':');
    final h = int.tryParse(parts.first) ?? 9;
    final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    final hour = h % 12;
    final ampm = h < 12 ? 'AM' : 'PM';
    final hourStr = hour == 0 ? '12' : hour.toString();
    return '$hourStr:${m.toString().padLeft(2, '0')} $ampm';
  }

  Future<void> _showTimePickerAndSave(
    BuildContext context,
    String currentTime,
    bool isMorning,
    AppTheme theme,
  ) async {
    final parts = currentTime.split(':');
    final initialHour = int.tryParse(parts.first) ?? 9;
    final initialMinute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initialHour, minute: initialMinute),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: theme.accentColor,
              onPrimary: Colors.white,
              surface: theme.gradientColors.first,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null || !mounted) return;

    final hhmm = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    if (isMorning) {
      await _storage.setMorningNotificationTime(hhmm);
      setState(() => _morningTime = hhmm);
    } else {
      await _storage.setEveningNotificationTime(hhmm);
      setState(() => _eveningTime = hhmm);
    }
    await _notif.applySettings();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reminder updated to ${_formatTimeForDisplay(hhmm)}', style: GoogleFonts.poppins()),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildNotificationsSection(BuildContext context, AppTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Notifications'),
        if (!_notificationPermissionGranted) ...[
          const SizedBox(height: 8),
          Material(
            color: Colors.orange.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () async {
                await openAppSettings();
                await Future.delayed(const Duration(milliseconds: 500));
                if (mounted) {
                  final granted = await _notif.hasPermission();
                  setState(() => _notificationPermissionGranted = granted);
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber, color: Colors.orange, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Notifications disabled. Enable in system settings.',
                        style: GoogleFonts.poppins(fontSize: 13, color: Colors.white),
                      ),
                    ),
                    const Icon(Icons.open_in_new, size: 18, color: Colors.white70),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 8),
        SwitchListTile(
          value: _notificationsEnabled && _notificationPermissionGranted,
          onChanged: (v) async {
            setState(() => _notificationLoading = true);
            HapticFeedback.lightImpact();
            if (v) {
              final granted = await _notif.requestPermission();
              if (!mounted) return;
              if (!granted) {
                setState(() {
                  _notificationPermissionGranted = false;
                  _notificationLoading = false;
                });
                if (mounted) {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text('Enable notifications', style: GoogleFonts.poppins()),
                      content: Text(
                        'Enable notifications in Settings to receive daily reminders.',
                        style: GoogleFonts.poppins(),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text('OK', style: GoogleFonts.poppins()),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            openAppSettings();
                          },
                          child: Text('Open Settings', style: GoogleFonts.poppins()),
                        ),
                      ],
                    ),
                  );
                }
                return;
              }
              setState(() => _notificationPermissionGranted = true);
            }
            await _storage.setNotificationsEnabled(v);
            if (v) {
              await _notif.applySettings();
            } else {
              await _notif.cancelAllReminders();
            }
            if (mounted) setState(() {
              _notificationsEnabled = v;
              _notificationLoading = false;
            });
          },
          title: Text(
            'Daily Reminders',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          activeColor: theme.accentColor,
        ),
        if (_notificationLoading)
          const Padding(
            padding: EdgeInsets.only(left: 16),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
            ),
          ),
        if (_notificationsEnabled && _notificationPermissionGranted) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () async {
              await _notif.showNotification(
                'Daily Rabbit',
                'GM! Check your daily affirmation 🐰',
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Test notification sent', style: GoogleFonts.poppins()),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            icon: const Icon(Icons.notifications_active, size: 20, color: Colors.white70),
            label: Text('Send test notification', style: GoogleFonts.poppins(color: Colors.white70)),
          ),
          const SizedBox(height: 4),
          _buildReminderRow(
            context,
            theme,
            label: 'Morning',
            enabled: _morningEnabled,
            time: _morningTime,
            isMorning: true,
          ),
          const SizedBox(height: 4),
          _buildReminderRow(
            context,
            theme,
            label: 'Evening',
            enabled: _eveningEnabled,
            time: _eveningTime,
            isMorning: false,
          ),
        ],
      ],
    );
  }

  Widget _buildReminderRow(
    BuildContext context,
    AppTheme theme, {
    required String label,
    required bool enabled,
    required String time,
    required bool isMorning,
  }) {
    return Material(
      color: Colors.white.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '$label Reminder',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: enabled ? Colors.white : Colors.white54,
                ),
              ),
            ),
            GestureDetector(
              onTap: enabled
                  ? () => _showTimePickerAndSave(context, time, isMorning, theme)
                  : null,
              child: Text(
                _formatTimeForDisplay(time),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: enabled ? theme.accentColor : Colors.white38,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Switch(
              value: enabled,
              onChanged: (v) async {
                HapticFeedback.lightImpact();
                if (isMorning) {
                  await _storage.setMorningNotificationEnabled(v);
                  setState(() => _morningEnabled = v);
                } else {
                  await _storage.setEveningNotificationEnabled(v);
                  setState(() => _eveningEnabled = v);
                }
                await _notif.applySettings();
              },
              activeColor: theme.accentColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      color: Colors.white.withValues(alpha: 0.2),
      thickness: 1,
      height: 1,
    );
  }

  Widget _buildSaveResetButtons(
    BuildContext context,
    AppTheme theme,
    ThemeNotifier themeNotifier,
    WalletState wallet,
    SettingsNotifier settings,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          onPressed: () async {
            HapticFeedback.lightImpact();
            await _storage.setName(_nameController.text.isEmpty ? 'Friend' : _nameController.text);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Settings saved', style: GoogleFonts.poppins()),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          },
          style: FilledButton.styleFrom(
            backgroundColor: theme.accentColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text('Save Changes', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text('Reset to default?', style: GoogleFonts.poppins()),
                content: Text(
                  'This will reset name, theme, haptic, and filter to their default values.',
                  style: GoogleFonts.poppins(),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: Text('Cancel', style: GoogleFonts.poppins()),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: Text('Reset', style: GoogleFonts.poppins()),
                  ),
                ],
              ),
            );
            if (confirm != true || !context.mounted) return;
            HapticFeedback.lightImpact();
            _nameController.text = 'Friend';
            await _storage.setName('Friend');
            await _storage.setHapticEnabled(true);
            await themeNotifier.setTheme(AppTheme.midnightBlue);
            await settings.setFavoritesOnly(false);
            setState(() => _haptic = true);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Settings reset to default', style: GoogleFonts.poppins()),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white70,
            side: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text('Reset to Default', style: GoogleFonts.poppins()),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<ThemeNotifier, WalletState, SettingsNotifier>(
      builder: (context, themeNotifier, wallet, settings, _) {
        final theme = themeNotifier.theme;
        return Scaffold(
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(gradient: theme.gradient),
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Settings',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Material(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ReleaseNotesScreen(),
                        ),
                      ),
                      borderRadius: BorderRadius.circular(12),
                      child: ListTile(
                        leading: Icon(Icons.new_releases, color: theme.accentColor, size: 24),
                        title: Text(
                          "What's New",
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                        subtitle: Text(
                          'Features and release notes',
                          style: GoogleFonts.poppins(fontSize: 12, color: Colors.white54),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white54),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Personalization'),
                  const SizedBox(height: 12),
                  Text(
                    'Name',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _nameController,
                    style: GoogleFonts.poppins(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Your name',
                      hintStyle: GoogleFonts.poppins(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.white12,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onSubmitted: _saveName,
                    onChanged: (v) => _saveName(v),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Theme',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...AppTheme.all.map((t) {
                    final selected = themeNotifier.theme.id == t.id;
                    return RadioListTile<ThemeId>(
                      value: t.id,
                      groupValue: themeNotifier.theme.id,
                      onChanged: (_) => themeNotifier.setTheme(t),
                      title: Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: t.accentColor,
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(
                                  color: t.accentColor.withValues(alpha: 0.5),
                                  blurRadius: 4,
                                  spreadRadius: 0,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            t.displayName,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                      activeColor: theme.accentColor,
                    );
                  }),
                  const SizedBox(height: 24),
                  _buildDivider(),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Preferences'),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: _haptic,
                    onChanged: (v) async {
                      await _storage.setHapticEnabled(v);
                      if (v) HapticFeedback.lightImpact();
                      setState(() => _haptic = v);
                    },
                    title: Text(
                      'Haptic feedback',
                      style: GoogleFonts.poppins(color: Colors.white),
                    ),
                    activeColor: theme.accentColor,
                  ),
                  SwitchListTile(
                    value: _showOnChainAnalytics,
                    onChanged: (v) async {
                      await _storage.setShowOnChainAnalytics(v);
                      setState(() => _showOnChainAnalytics = v);
                    },
                    title: Text(
                      'Show on-chain analytics',
                      style: GoogleFonts.poppins(color: Colors.white),
                    ),
                    subtitle: Text(
                      'Display blockchain activity dashboard on Profile',
                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.white54),
                    ),
                    activeColor: theme.accentColor,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Affirmation filter',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                  Consumer<SettingsNotifier>(
                    builder: (context, settings, _) {
                      return Row(
                        children: [
                          ChoiceChip(
                            label: const Text('All'),
                            selected: !settings.favoritesOnly,
                            onSelected: (_) => settings.setFavoritesOnly(false),
                            selectedColor: theme.accentColor.withOpacity(0.5),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Favorites'),
                            selected: settings.favoritesOnly,
                            onSelected: (_) => settings.setFavoritesOnly(true),
                            selectedColor: theme.accentColor.withOpacity(0.5),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Start screen',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _startScreen,
                        isExpanded: true,
                        dropdownColor: theme.gradientColors.first,
                        style: GoogleFonts.poppins(color: Colors.white),
                        items: const [
                          DropdownMenuItem(value: 'main', child: Text('Main')),
                          DropdownMenuItem(value: 'task', child: Text('Task')),
                          DropdownMenuItem(value: 'minigame', child: Text('Mini game')),
                          DropdownMenuItem(value: 'defi', child: Text('DeFi')),
                          DropdownMenuItem(value: 'profile', child: Text('Profile')),
                        ],
                        onChanged: (v) async {
                          if (v != null) {
                            await _storage.setStartScreen(v);
                            setState(() => _startScreen = v);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildDivider(),
                  const SizedBox(height: 24),
                  _buildNotificationsSection(context, theme),
                  const SizedBox(height: 24),
                  _buildDivider(),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Account'),
                  const SizedBox(height: 12),
                  Text(
                    'Favorites',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Consumer<AffirmationService>(
                    builder: (context, affService, _) {
                      final favorites = affService.favorites;
                      if (favorites.isEmpty) {
                        return Text(
                          'No favorites yet. Tap ❤️ on the main screen.',
                          style: GoogleFonts.poppins(color: Colors.white54, fontSize: 14),
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: favorites.map((a) {
                          return Card(
                            color: Colors.white12,
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(
                                a.text,
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.share, color: Colors.white70),
                                    onPressed: () => Share.share(a.text),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                    onPressed: () async {
                                      await affService.toggleFavorite(a);
                                      setState(() {});
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  if (wallet.isConnected) ...[
                    Text(
                      'Wallet',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      wallet.truncatedAddress,
                      style: GoogleFonts.poppins(
                        color: theme.accentColor,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const NotificationDebugScreen()),
                    ),
                    icon: const Icon(Icons.notifications_active, color: Colors.white70),
                    label: Text(
                      'Debug Logs',
                      style: GoogleFonts.poppins(color: Colors.white),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white38),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ErrorLogsScreen()),
                    ),
                    icon: const Icon(Icons.bug_report, color: Colors.white70),
                    label: Text(
                      'Error logs',
                      style: GoogleFonts.poppins(color: Colors.white),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white38),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildDivider(),
                  const SizedBox(height: 24),
                  _buildSectionTitle('About'),
                  const SizedBox(height: 12),
                  _buildAboutSection(theme),
                  const SizedBox(height: 32),
                  _buildDivider(),
                  const SizedBox(height: 24),
                  _buildSaveResetButtons(context, theme, themeNotifier, wallet, settings),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
