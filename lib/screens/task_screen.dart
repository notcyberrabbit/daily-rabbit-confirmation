import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_device_apps/flutter_device_apps.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_theme.dart';
import '../models/task.dart';
import '../providers/theme_notifier.dart';
import '../services/storage_service.dart';
import '../services/widget_update_service.dart';

/// Daily Tasks screen: list with add, toggle complete, edit, delete, priority, filters, swipe.
class TaskScreen extends StatefulWidget {
  const TaskScreen({super.key});

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> with WidgetsBindingObserver {
  final StorageService _storage = StorageService();
  final TextEditingController _quickAddController = TextEditingController();
  final FocusNode _quickAddFocus = FocusNode();
  List<TaskItem> _tasks = [];
  bool _loading = true;
  String _filter = 'all';
  int _taskStreak = 0;
  bool _autoReset = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadTasks();
    _loadFilter();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _quickAddController.dispose();
    _quickAddFocus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkMidnightResetAndReload();
    }
  }

  Future<void> _loadTasks() async {
    await _storage.init();
    final list = await _storage.getTasks();
    var tasks = list.map(TaskItem.fromJson).toList();
    final autoReset = await _storage.getTaskAutoReset();
    if (mounted) setState(() => _autoReset = autoReset);
    if (autoReset) tasks = await _checkMidnightReset(tasks);
    final streak = await _storage.getTaskStreak();
    if (mounted) {
      setState(() {
        _tasks = tasks;
        _taskStreak = streak;
        _loading = false;
      });
    }
  }

  Future<void> _checkMidnightResetAndReload() async {
    if (_loading) return;
    await _storage.init();
    final autoReset = await _storage.getTaskAutoReset();
    if (!autoReset) return;
    final list = await _storage.getTasks();
    var tasks = list.map(TaskItem.fromJson).toList();
    final afterReset = await _checkMidnightReset(tasks);
    if (afterReset != tasks && mounted) {
      final streak = await _storage.getTaskStreak();
      setState(() {
        _tasks = afterReset;
        _taskStreak = streak;
      });
    }
  }

  /// If last reset was before today: save that day's stats, reset checkboxes, return new list.
  Future<List<TaskItem>> _checkMidnightReset(List<TaskItem> tasks) async {
    final today = _dateStr(DateTime.now());
    final lastReset = await _storage.getTaskLastResetDate();
    if (lastReset == null) {
      await _storage.setTaskLastResetDate(today);
      return tasks;
    }
    if (lastReset.compareTo(today) >= 0) return tasks;

    final completed = tasks.where((t) => t.completed).length;
    final total = tasks.length;
    final completedMin = tasks.where((t) => t.completed && t.estimatedMinutes != null).fold<int>(0, (s, t) => s + (t.estimatedMinutes ?? 0));
    final totalMin = tasks.where((t) => t.estimatedMinutes != null).fold<int>(0, (s, t) => s + (t.estimatedMinutes ?? 0));

    await _storage.appendTaskDayLog({
      'date': lastReset,
      'completedCount': completed,
      'totalCount': total,
      'completedMinutes': completedMin,
      'totalMinutes': totalMin,
    });

    final allDone = total > 0 && completed == total;
    final streak = await _storage.getTaskStreak();
    await _storage.setTaskStreak(allDone ? streak + 1 : 0);

    final reset = tasks.map((t) => t.copyWith(completed: false)).toList();
    await _storage.setTasks(reset.map((t) => t.toJson()).toList());
    await _storage.setTaskLastResetDate(today);
    if (Platform.isAndroid) WidgetUpdateService.notifyWidgetUpdate();
    return reset;
  }

  String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _loadFilter() async {
    await _storage.init();
    final f = await _storage.getTasksFilter();
    if (mounted) setState(() => _filter = f);
  }

  Future<void> _toggleAutoReset() async {
    HapticFeedback.lightImpact();
    final v = !_autoReset;
    setState(() => _autoReset = v);
    await _storage.setTaskAutoReset(v);
  }

  Future<void> _saveTasks() async {
    await _storage.setTasks(_tasks.map((t) => t.toJson()).toList());
    if (Platform.isAndroid) WidgetUpdateService.notifyWidgetUpdate();
  }

  Future<void> _saveFilter() async {
    await _storage.setTasksFilter(_filter);
  }

  List<TaskItem> get _sortedTasks {
    final list = List<TaskItem>.from(_tasks);
    final priorityOrder = {TaskPriority.urgent: 0, TaskPriority.normal: 1, TaskPriority.low: 2};
    list.sort((a, b) {
      final pa = priorityOrder[a.priority] ?? 1;
      final pb = priorityOrder[b.priority] ?? 1;
      if (pa != pb) return pa.compareTo(pb);
      final da = a.createdAt ?? DateTime(0);
      final db = b.createdAt ?? DateTime(0);
      return db.compareTo(da);
    });
    return list;
  }

  List<TaskItem> get _filteredTasks {
    final sorted = _sortedTasks;
    switch (_filter) {
      case 'active':
        return sorted.where((t) => !t.completed).toList();
      case 'completed':
        return sorted.where((t) => t.completed).toList();
      default:
        return sorted;
    }
  }

  Future<void> _resetAllTasks() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Uncheck All Tasks?', style: GoogleFonts.poppins()),
        content: Text(
          'This will uncheck all completed tasks',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Uncheck All', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() {
      for (var i = 0; i < _tasks.length; i++) {
        if (_tasks[i].completed) {
          _tasks[i] = _tasks[i].copyWith(completed: false);
        }
      }
    });
    await _saveTasks();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('All tasks unchecked', style: GoogleFonts.poppins()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _addTaskFromText(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      _tasks.add(TaskItem(
        id: '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(10000)}',
        text: trimmed,
        createdAt: DateTime.now(),
      ));
    });
    _saveTasks();
    _quickAddController.clear();
    _quickAddFocus.requestFocus();
  }

  Future<void> _addTask() async {
    final result = await _showTaskDialog(
      context,
      title: 'Add Task',
      initialText: '',
      initialPackage: null,
      initialAppName: null,
      initialUrl: null,
      initialPriority: TaskPriority.normal,
      initialEstimatedMinutes: null,
    );
    if (result == null || result.$1.isEmpty || !mounted) return;
    HapticFeedback.lightImpact();
    setState(() {
      _tasks.add(TaskItem(
        id: '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(10000)}',
        text: result.$1.trim(),
        linkedPackage: result.$2,
        linkedAppName: result.$3,
        linkedUrl: result.$4,
        priority: result.$5,
        createdAt: DateTime.now(),
        estimatedMinutes: result.$6,
      ));
    });
    await _saveTasks();
  }

  Future<void> _editTask(TaskItem task) async {
    final result = await _showTaskDialog(
      context,
      title: 'Edit Task',
      initialText: task.text,
      initialPackage: task.linkedPackage,
      initialAppName: task.linkedAppName,
      initialUrl: task.linkedUrl,
      initialPriority: task.priority,
      initialEstimatedMinutes: task.estimatedMinutes,
    );
    if (result == null || !mounted) return;
    setState(() {
      final i = _tasks.indexWhere((t) => t.id == task.id);
      if (i >= 0) {
        _tasks[i] = task.copyWith(
          text: result.$1.trim(),
          linkedPackage: result.$2,
          linkedAppName: result.$3,
          linkedUrl: result.$4,
          priority: result.$5,
          estimatedMinutes: result.$6,
        );
      }
    });
    await _saveTasks();
  }

  Future<void> _openTaskLink(TaskItem task) async {
    if (task.hasLinkedUrl) {
      final uri = Uri.tryParse(task.linkedUrl!.trim());
      if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
        try {
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Could not open link', style: GoogleFonts.poppins()),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
      return;
    }
    if (task.hasLinkedApp && Platform.isAndroid) {
      try {
        await FlutterDeviceApps.openApp(task.linkedPackage!);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not open app', style: GoogleFonts.poppins()),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Future<void> _toggleTask(TaskItem task) async {
    HapticFeedback.lightImpact();
    setState(() {
      final i = _tasks.indexWhere((t) => t.id == task.id);
      if (i >= 0) _tasks[i] = task.copyWith(completed: !task.completed);
    });
    await _saveTasks();
  }

  Future<void> _deleteTask(TaskItem task, {bool showUndo = false}) async {
    if (showUndo) {
      final deleted = task;
      setState(() => _tasks.removeWhere((t) => t.id == task.id));
      await _saveTasks();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Task deleted', style: GoogleFonts.poppins()),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            persist: false,
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () {
                setState(() => _tasks.add(deleted));
                _saveTasks();
              },
            ),
          ),
        );
      }
    } else {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Delete task?', style: GoogleFonts.poppins()),
          content: Text(
            task.text,
            style: GoogleFonts.poppins(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Cancel', style: GoogleFonts.poppins()),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text('Delete', style: GoogleFonts.poppins(color: Colors.red)),
            ),
          ],
        ),
      );
      if (confirm != true || !mounted) return;
      setState(() => _tasks.removeWhere((t) => t.id == task.id));
      await _saveTasks();
    }
  }

  Future<void> _showPriorityDialog(TaskItem task) async {
    final result = await showDialog<TaskPriority>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Priority', style: GoogleFonts.poppins()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: TaskPriority.values.map((p) {
            final color = _priorityColor(p);
            return ListTile(
              leading: Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              title: Text(p.name[0].toUpperCase() + p.name.substring(1), style: GoogleFonts.poppins()),
              onTap: () => Navigator.of(ctx).pop(p),
            );
          }).toList(),
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        final i = _tasks.indexWhere((t) => t.id == task.id);
        if (i >= 0) _tasks[i] = task.copyWith(priority: result);
      });
      await _saveTasks();
    }
  }

  Color _priorityColor(TaskPriority p) {
    switch (p) {
      case TaskPriority.urgent:
        return const Color(0xFFFF5252);
      case TaskPriority.normal:
        return const Color(0xFFFFC107);
      case TaskPriority.low:
        return const Color(0xFF48CAE4);
    }
  }

  Future<(String, String?, String?, String?, TaskPriority, int?)?> _showTaskDialog(
    BuildContext context, {
    required String title,
    String initialText = '',
    String? initialPackage,
    String? initialAppName,
    String? initialUrl,
    TaskPriority initialPriority = TaskPriority.normal,
    int? initialEstimatedMinutes,
  }) async {
    final controller = TextEditingController(text: initialText);
    final urlController = TextEditingController(text: initialUrl ?? '');
    final estController = TextEditingController(text: initialEstimatedMinutes != null ? '$initialEstimatedMinutes' : '');
    String? linkedPackage = initialPackage;
    String? linkedAppName = initialAppName;
    TaskPriority priority = initialPriority;
    return showDialog<(String, String?, String?, String?, TaskPriority, int?)?>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(title, style: GoogleFonts.poppins()),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: controller,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Task description',
                        border: const OutlineInputBorder(),
                      ),
                      style: GoogleFonts.poppins(),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    Text('Priority', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Row(
                      children: TaskPriority.values.map((p) {
                        final c = _priorityColor(p);
                        final sel = priority == p;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            selected: sel,
                            label: Text(p.name),
                            onSelected: (_) => setDialogState(() => priority = p),
                            selectedColor: c.withValues(alpha: 0.3),
                            checkmarkColor: c,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Text('Est. time (minutes)', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: estController,
                      decoration: const InputDecoration(
                        hintText: 'e.g. 10',
                        border: OutlineInputBorder(),
                      ),
                      style: GoogleFonts.poppins(fontSize: 14),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    Text('Link URL (optional)', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: urlController,
                      decoration: InputDecoration(
                        hintText: 'https://...',
                        border: const OutlineInputBorder(),
                      ),
                      style: GoogleFonts.poppins(fontSize: 14),
                      keyboardType: TextInputType.url,
                    ),
                    if (Platform.isAndroid) ...[
                      const SizedBox(height: 16),
                      Text('Link app (optional)', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              linkedAppName ?? 'None',
                              style: GoogleFonts.poppins(fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              final picked = await _showAppPicker(context);
                              if (picked != null) {
                                setDialogState(() {
                                  linkedPackage = picked.$1;
                                  linkedAppName = picked.$2;
                                });
                              }
                            },
                            icon: const Icon(Icons.apps, size: 20),
                            label: Text(linkedPackage != null ? 'Change' : 'Choose app', style: GoogleFonts.poppins(fontSize: 12)),
                          ),
                          if (linkedPackage != null)
                            IconButton(
                              icon: const Icon(Icons.close, size: 20),
                              onPressed: () => setDialogState(() {
                                linkedPackage = null;
                                linkedAppName = null;
                              }),
                              tooltip: 'Remove app link',
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text('Cancel', style: GoogleFonts.poppins()),
                ),
                FilledButton(
                  onPressed: () {
                    final url = urlController.text.trim();
                    final estStr = estController.text.trim();
                    final est = int.tryParse(estStr);
                    Navigator.of(ctx).pop((
                      controller.text.trim(),
                      linkedPackage,
                      linkedAppName,
                      url.isNotEmpty ? url : null,
                      priority,
                      est != null && est > 0 ? est : null,
                    ));
                  },
                  child: Text('Save', style: GoogleFonts.poppins()),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<(String package, String appName)?> _showAppPicker(BuildContext context) async {
    if (!Platform.isAndroid) return null;
    List<AppInfo> apps;
    try {
      apps = await FlutterDeviceApps.listApps(
        includeSystem: false,
        onlyLaunchable: true,
        includeIcons: false,
      );
    } catch (_) {
      return null;
    }
    apps.sort((a, b) => (a.appName ?? '').toLowerCase().compareTo((b.appName ?? '').toLowerCase()));
    if (!context.mounted) return null;
    return showModalBottomSheet<(String, String)?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Choose app', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: apps.length,
                itemBuilder: (context, index) {
                  final app = apps[index];
                  final package = app.packageName ?? '';
                  final name = app.appName ?? package;
                  if (package.isEmpty) return const SizedBox.shrink();
                  return ListTile(
                    title: Text(name, style: GoogleFonts.poppins()),
                    subtitle: Text(package, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey), overflow: TextOverflow.ellipsis),
                    onTap: () => Navigator.of(ctx).pop((package, name)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeNotifier>(
      builder: (context, themeNotifier, _) {
        final theme = themeNotifier.theme;
        return Scaffold(
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(gradient: theme.gradient),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(context, theme),
                  if (!_loading) _buildProgressSection(theme),
                  if (!_loading) _buildFilterChips(theme),
                  if (!_loading) _buildAutoResetToggle(theme),
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator(color: Colors.white70))
                        : _buildTaskList(theme),
                  ),
                  if (!_loading) _buildQuickAdd(theme),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, AppTheme theme) {
    final today = DateTime.now();
    final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Tasks',
                  style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Text('Today · $dateStr', style: GoogleFonts.poppins(fontSize: 13, color: Colors.white70)),
              ],
            ),
          ),
          GestureDetector(
            onTap: _showStreakLog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _taskStreak > 0 ? theme.accentColor.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _taskStreak > 0 ? theme.accentColor : Colors.white24,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🔥', style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 4),
                  Text(
                    '$_taskStreak',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _resetAllTasks,
            tooltip: 'Uncheck all',
          ),
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: _addTask,
            tooltip: 'Add Task',
          ),
        ],
      ),
    );
  }

  Future<void> _showStreakLog() async {
    await _storage.init();
    final log = await _storage.getTaskDailyLog();
    final entries = log.map((m) => TaskDayLog.fromJson(m)).toList();
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.6),
        decoration: BoxDecoration(
          color: const Color(0xFF1a1a2e),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Text('🔥 $_taskStreak day streak', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close, color: Colors.white70), onPressed: () => Navigator.of(ctx).pop()),
                ],
              ),
            ),
            const Divider(height: 1, color: Colors.white12),
            Flexible(
              child: entries.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'Complete all tasks to build your streak.\nLog appears after midnight reset.',
                        style: GoogleFonts.poppins(fontSize: 14, color: Colors.white54),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: entries.length,
                      itemBuilder: (_, i) {
                        final e = entries[i];
                        return ListTile(
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor: e.allDone ? Colors.green.withValues(alpha: 0.4) : Colors.white12,
                            child: Text(e.allDone ? '✓' : '${e.completedCount}', style: GoogleFonts.poppins(fontSize: 12, color: Colors.white)),
                          ),
                          title: Text(
                            e.date,
                            style: GoogleFonts.poppins(fontSize: 14, color: Colors.white),
                          ),
                          subtitle: Text(
                            '${e.completedCount}/${e.totalCount} tasks' + (e.totalMinutes > 0 ? ' · ${e.completedMinutes}/${e.totalMinutes} min' : ''),
                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.white54),
                          ),
                          trailing: e.allDone ? const Icon(Icons.local_fire_department, color: Colors.orange, size: 24) : null,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressSection(AppTheme theme) {
    final total = _tasks.length;
    final completed = _tasks.where((t) => t.completed).length;
    final pct = total > 0 ? completed / total : 0.0;
    final totalMin = _tasks.where((t) => t.estimatedMinutes != null).fold<int>(0, (s, t) => s + (t.estimatedMinutes ?? 0));
    final completedMin = _tasks.where((t) => t.completed && t.estimatedMinutes != null).fold<int>(0, (s, t) => s + (t.estimatedMinutes ?? 0));
    final remainingMin = totalMin - completedMin;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$total Total tasks',
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70),
              ),
              Text(
                '$completed Completed (${total > 0 ? (pct * 100).round() : 0}%)',
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
          if (totalMin > 0) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '⏱ ${completedMin} min done',
                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.white54),
                ),
                Text(
                  '${remainingMin} min left today',
                  style: GoogleFonts.poppins(fontSize: 11, color: theme.accentColor),
                ),
              ],
            ),
          ],
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(
                pct >= 1.0 ? Colors.green : theme.accentColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(AppTheme theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildFilterChip('All', 'all'),
          const SizedBox(width: 8),
          _buildFilterChip('Active', 'active'),
          const SizedBox(width: 8),
          _buildFilterChip('Completed', 'completed'),
        ],
      ),
    );
  }

  Widget _buildAutoResetToggle(AppTheme theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.nightlight_round, size: 18, color: Colors.white54),
          const SizedBox(width: 8),
          Text(
            'Auto reset at midnight',
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.white70),
          ),
          const Spacer(),
          Switch(
            value: _autoReset,
            onChanged: (_) => _toggleAutoReset(),
            activeTrackColor: theme.accentColor.withValues(alpha: 0.5),
            activeThumbColor: theme.accentColor,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final selected = _filter == value;
    return FilterChip(
      label: Text(label, style: GoogleFonts.poppins(fontSize: 12)),
      selected: selected,
      onSelected: (_) async {
        setState(() => _filter = value);
        await _saveFilter();
      },
      selectedColor: Colors.white.withValues(alpha: 0.3),
      checkmarkColor: Colors.white,
      backgroundColor: Colors.white.withValues(alpha: 0.1),
      labelStyle: TextStyle(color: selected ? Colors.white : Colors.white70),
    );
  }

  Widget _buildQuickAdd(AppTheme theme) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _quickAddController,
              focusNode: _quickAddFocus,
              decoration: InputDecoration(
                hintText: 'Type task here...',
                hintStyle: GoogleFonts.poppins(color: Colors.white54),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              style: GoogleFonts.poppins(color: Colors.white),
              textInputAction: TextInputAction.done,
              onSubmitted: _addTaskFromText,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.add_circle, color: Colors.white),
            onPressed: () {
              final text = _quickAddController.text;
              _addTaskFromText(text);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTaskList(AppTheme theme) {
    final filtered = _filteredTasks;
    if (filtered.isEmpty) {
      return _buildEmptyState(theme);
    }
    if (_filter == 'all') {
      return ReorderableListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: filtered.length,
        onReorder: (oldIndex, newIndex) async {
          final sorted = List<TaskItem>.from(_sortedTasks);
          if (newIndex > oldIndex) newIndex--;
          final item = sorted.removeAt(oldIndex);
          sorted.insert(newIndex, item);
          setState(() => _tasks = sorted);
          await _saveTasks();
        },
        itemBuilder: (context, index) {
          final task = filtered[index];
          final globalIndex = _sortedTasks.indexWhere((t) => t.id == task.id);
          return _TaskTile(
            key: ValueKey(task.id),
            index: globalIndex >= 0 ? globalIndex : index,
            task: task,
            theme: theme,
            priorityColor: _priorityColor(task.priority),
            onToggle: () => _toggleTask(task),
            onEdit: () => _editTask(task),
            onDeleteSwipe: () => _deleteTask(task, showUndo: true),
            onDeleteButton: () => _deleteTask(task, showUndo: false),
            onOpenLink: () => _openTaskLink(task),
            onPriority: () => _showPriorityDialog(task),
          );
        },
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final task = filtered[index];
        final globalIndex = _sortedTasks.indexWhere((t) => t.id == task.id);
        return _TaskTile(
          key: ValueKey(task.id),
          index: globalIndex >= 0 ? globalIndex : index,
          task: task,
          theme: theme,
          priorityColor: _priorityColor(task.priority),
          onToggle: () => _toggleTask(task),
          onEdit: () => _editTask(task),
          onDeleteSwipe: () => _deleteTask(task, showUndo: true),
          onDeleteButton: () => _deleteTask(task, showUndo: false),
          onOpenLink: () => _openTaskLink(task),
          onPriority: () => _showPriorityDialog(task),
        );
      },
    );
  }

  Widget _buildEmptyState(AppTheme theme) {
    String message;
    switch (_filter) {
      case 'active':
        message = 'All done! 🎉';
        break;
      case 'completed':
        message = 'No completed tasks yet';
        break;
      default:
        message = 'No tasks yet. Add one below!';
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.white38),
            const SizedBox(height: 16),
            Text(
              message,
              style: GoogleFonts.poppins(fontSize: 18, color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    super.key,
    required this.index,
    required this.task,
    required this.theme,
    required this.priorityColor,
    required this.onToggle,
    required this.onEdit,
    required this.onDeleteSwipe,
    required this.onDeleteButton,
    required this.onOpenLink,
    required this.onPriority,
  });

  final int index;
  final TaskItem task;
  final AppTheme theme;
  final Color priorityColor;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDeleteSwipe;
  final VoidCallback onDeleteButton;
  final VoidCallback onOpenLink;
  final VoidCallback onPriority;

  @override
  Widget build(BuildContext context) {
    final linkHint = task.hasLinkedUrl
        ? '🔗 ${task.linkedUrl!.length > 40 ? '${task.linkedUrl!.substring(0, 40)}...' : task.linkedUrl}'
        : (task.hasLinkedApp && task.linkedAppName != null)
            ? '📱 ${task.linkedAppName}'
            : null;
    return Dismissible(
      key: ValueKey('dismiss_${task.id}'),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          HapticFeedback.lightImpact();
          onToggle();
          return false;
        }
        if (direction == DismissDirection.endToStart) {
          HapticFeedback.mediumImpact();
          onDeleteSwipe();
          return true;
        }
        return false;
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 8),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.check, color: Colors.white, size: 32),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.only(bottom: 8),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white, size: 32),
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        color: Colors.white.withValues(alpha: task.completed ? 0.08 : 0.14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: priorityColor,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
              ),
            ),
            Expanded(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                leading: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ReorderableDragStartListener(
                      index: index,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(Icons.drag_handle, color: Colors.white54, size: 22),
                      ),
                    ),
                    Checkbox(
                      value: task.completed,
                      onChanged: (_) => onToggle(),
                      activeColor: theme.accentColor,
                      fillColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) return theme.accentColor;
                        return Colors.white24;
                      }),
                    ),
                  ],
                ),
                title: GestureDetector(
                  onDoubleTap: task.hasLink ? onOpenLink : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              task.text,
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: task.completed ? Colors.white54 : Colors.white,
                                decoration: task.completed ? TextDecoration.lineThrough : null,
                                decorationColor: Colors.white54,
                              ),
                            ),
                          ),
                          if (task.estimatedMinutes != null)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${task.estimatedMinutes} min',
                                style: GoogleFonts.poppins(fontSize: 11, color: Colors.white70),
                              ),
                            ),
                        ],
                      ),
                      if (linkHint != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            '$linkHint · double-tap to open',
                            style: GoogleFonts.poppins(fontSize: 11, color: Colors.white54),
                          ),
                        ),
                    ],
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (task.hasLink)
                      IconButton(
                        icon: Icon(Icons.open_in_new, size: 20, color: theme.accentColor),
                        onPressed: onOpenLink,
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        tooltip: task.hasLinkedUrl ? 'Open link' : 'Open app',
                      ),
                    IconButton(
                      icon: Icon(Icons.lens, size: 16, color: priorityColor),
                      onPressed: onPriority,
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      tooltip: 'Priority',
                    ),
                    IconButton(
                      icon: Icon(Icons.edit_outlined, size: 20, color: Colors.white70),
                      onPressed: onEdit,
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline, size: 20, color: Colors.white70),
                      onPressed: onDeleteButton,
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
