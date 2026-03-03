import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/app_theme.dart';
import '../providers/theme_notifier.dart';
import '../services/storage_service.dart';

/// Tap the Rabbit mini-game: rabbit moves on screen; tap on rabbit +1 carrot, tap miss -1 carrot.
/// 100 taps per 8h session. Combo, particles, rabbit reactions, idle breathing.
class MiniplayScreen extends StatefulWidget {
  const MiniplayScreen({super.key});

  @override
  State<MiniplayScreen> createState() => _MiniplayScreenState();
}

class _MiniplayScreenState extends State<MiniplayScreen>
    with TickerProviderStateMixin {
  final StorageService _storage = StorageService();

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _tapController;
  late Animation<double> _tapScaleAnimation;
  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;
  late AnimationController _comboPulseController;

  int _tapsRemaining = 100;
  int _totalCarrots = 0;
  int? _minutesUntilNextSession;
  Timer? _countdownTimer;
  Timer? _moveTimer;
  Timer? _blinkTimer;
  bool _hapticEnabled = true;
  final List<_FlyingCarrot> _flyingCarrots = [];
  Offset _rabbitOffset = Offset.zero;
  double _areaWidth = 0;
  double _areaHeight = 0;
  static const double _rabbitSize = 120;
  static const double _hitRadius = 42; // smaller = harder to hit
  final Random _random = Random();

  // Combo: increment if tap within 0.5s of previous hit
  int _combo = 0;
  DateTime? _lastTapHitTime;
  static const _comboWindowMs = 500;

  // Milestone effects (25, 50, 75, 100 taps used)
  double _shakeOffset = 0;
  double _flashOpacity = 0;

  @override
  void initState() {
    super.initState();
    // Idle breathing: subtle 1.0 → 1.05
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    // Tap bounce: 1.0 → 1.2 in 200ms
    _tapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _tapScaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _tapController, curve: Curves.bounceOut),
    );
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _blinkAnimation = Tween<double>(begin: 1, end: 0.3).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut),
    );
    _comboPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadState();
    _startCountdownTimer();
    _startMoveTimer();
    _startBlinkTimer();
  }

  void _startBlinkTimer() {
    _blinkTimer?.cancel();
    void scheduleBlink() {
      _blinkTimer = Timer(const Duration(seconds: 4), () {
        if (!mounted || _tapsRemaining <= 0) {
          scheduleBlink();
          return;
        }
        void onStatus(AnimationStatus status) {
          if (status == AnimationStatus.completed) {
            _blinkController.removeStatusListener(onStatus);
            _blinkController.reverse();
          }
        }
        _blinkController.addStatusListener(onStatus);
        _blinkController.forward(from: 0);
        scheduleBlink();
      });
    }
    scheduleBlink();
  }

  void _startMoveTimer() {
    _moveTimer?.cancel();
    // Faster, more dynamic jumping: random interval 900–1600 ms
    void scheduleNext() {
      _moveTimer = Timer(Duration(milliseconds: 900 + _random.nextInt(700)), () {
        if (!mounted || _areaWidth < _rabbitSize || _areaHeight < _rabbitSize) {
          scheduleNext();
          return;
        }
        final padding = _hitRadius + 24;
        final w = _areaWidth - 2 * padding;
        final h = _areaHeight - 2 * padding;
        if (w <= 0 || h <= 0) {
          scheduleNext();
          return;
        }
        setState(() {
          _rabbitOffset = Offset(
            padding + _random.nextDouble() * w,
            padding + _random.nextDouble() * h,
          );
        });
        scheduleNext();
      });
    }
    scheduleNext();
  }

  Future<void> _loadState() async {
    await _storage.init();
    _hapticEnabled = await _storage.getHapticEnabled();
    final taps = await _storage.getMiniplayTapsRemainingWithSessionReset();
    final carrots = await _storage.getMiniplayTotalCarrots();
    final minutes = await _storage.getMiniplayMinutesUntilNextSession();
    if (mounted) {
      setState(() {
        _tapsRemaining = taps;
        _totalCarrots = carrots;
        _minutesUntilNextSession = minutes;
      });
    }
  }

  void _startCountdownTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      final minutes = await _storage.getMiniplayMinutesUntilNextSession();
      if (minutes == null || minutes <= 0) {
        await _loadState();
        return;
      }
      if (mounted) {
        setState(() => _minutesUntilNextSession = minutes);
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _moveTimer?.cancel();
    _blinkTimer?.cancel();
    _pulseController.dispose();
    _tapController.dispose();
    _blinkController.dispose();
    _comboPulseController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (_tapsRemaining <= 0) return;
    final pos = details.localPosition;
    final dx = pos.dx - _rabbitOffset.dx - _rabbitSize / 2;
    final dy = pos.dy - _rabbitOffset.dy - _rabbitSize / 2;
    final hit = (dx * dx + dy * dy) <= (_hitRadius * _hitRadius);
    if (hit) {
      _onTapHit();
    } else {
      _onTapMiss();
    }
  }

  Future<void> _onTapHit() async {
    if (_tapsRemaining <= 0) return;
    if (_hapticEnabled) HapticFeedback.lightImpact();

    // Combo: within 0.5s of previous hit?
    final now = DateTime.now();
    final prev = _lastTapHitTime;
    if (prev != null && now.difference(prev).inMilliseconds <= _comboWindowMs) {
      _combo++;
    } else {
      _combo = 1;
    }
    _lastTapHitTime = now;

    // Bonus: +1 carrot every 10 combo
    var carrotBonus = 1;
    if (_combo > 0 && _combo % 10 == 0) carrotBonus = 2;

    void onStatus(AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        _tapController.removeStatusListener(onStatus);
        _tapController.reverse();
      }
    }
    _tapController.addStatusListener(onStatus);
    _tapController.forward(from: 0);

    final newTaps = _tapsRemaining - 1;
    final newTapsUsed = 100 - newTaps;
    final isMilestone = [25, 50, 75, 100].contains(newTapsUsed);

    _spawnParticles(count: isMilestone ? 12 : 3 + _random.nextInt(3));
    if (isMilestone) _triggerMilestoneEffects();

    final newCarrots = _totalCarrots + carrotBonus;
    await _storage.setMiniplayTapsRemaining(newTaps);
    await _storage.setMiniplayTotalCarrots(newCarrots);
    int? nextMin;
    if (newTaps == 0) {
      nextMin = await _storage.getMiniplayMinutesUntilNextSession();
    }
    if (mounted) {
      setState(() {
        _tapsRemaining = newTaps;
        _totalCarrots = newCarrots;
        if (nextMin != null) _minutesUntilNextSession = nextMin;
      });
    }
    void onComboPulseStatus(AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        _comboPulseController.removeStatusListener(onComboPulseStatus);
        _comboPulseController.reverse();
      }
    }
    _comboPulseController.addStatusListener(onComboPulseStatus);
    _comboPulseController.forward(from: 0);
  }

  Future<void> _onTapMiss() async {
    if (_tapsRemaining <= 0) return;
    if (_hapticEnabled) HapticFeedback.heavyImpact();
    _combo = 0;
    final newTaps = _tapsRemaining - 1;
    final newCarrots = (_totalCarrots - 1).clamp(0, 0x7fffffff);
    await _storage.setMiniplayTapsRemaining(newTaps);
    await _storage.setMiniplayTotalCarrots(newCarrots);
    int? nextMin;
    if (newTaps == 0) {
      nextMin = await _storage.getMiniplayMinutesUntilNextSession();
    }
    if (mounted) {
      setState(() {
        _tapsRemaining = newTaps;
        _totalCarrots = newCarrots;
        if (nextMin != null) _minutesUntilNextSession = nextMin;
      });
    }
  }

  void _spawnParticles({required int count}) {
    final baseX = _rabbitOffset.dx + _rabbitSize / 2;
    final baseY = _rabbitOffset.dy + _rabbitSize / 2;
    for (var i = 0; i < count; i++) {
      final particle = _FlyingCarrot(
        DateTime.now(),
        offsetX: (baseX - 20) + _random.nextDouble() * 40,
        offsetY: baseY - 20,
        spreadX: _random.nextDouble() * 1.6 - 0.8,
        rotation: _random.nextDouble() * 2 * pi - pi,
      );
      setState(() => _flyingCarrots.add(particle));
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted && _flyingCarrots.contains(particle)) {
          setState(() => _flyingCarrots.remove(particle));
        }
      });
    }
  }

  void _triggerMilestoneEffects() {
    // Screen shake: alternate left/right
    const offsets = [4.0, -4.0, 3.0, -3.0, 2.0, -2.0, 1.0, 0.0];
    for (var i = 0; i < offsets.length; i++) {
      final offset = offsets[i];
      Future.delayed(Duration(milliseconds: i * 35), () {
        if (!mounted) return;
        setState(() => _shakeOffset = offset);
      });
    }
    // Flash overlay
    setState(() => _flashOpacity = 0.7);
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _flashOpacity = 0.35);
    });
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _flashOpacity = 0);
    });
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
            child: Stack(
              children: [
                Transform.translate(
                  offset: Offset(_shakeOffset, 0),
                  child: SafeArea(
                    child: Column(
                    children: [
                      _buildAppBar(context),
                      Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildTapCounter(theme),
                        const SizedBox(height: 8),
                        _buildCarrotBalance(theme),
                        const SizedBox(height: 24),
                        _buildRabbitArea(theme),
                        if (_tapsRemaining <= 0) ...[
                          const SizedBox(height: 16),
                          _buildNextSessionTimer(theme),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
                if (_combo > 0) _buildComboOverlay(theme),
                if (_flashOpacity > 0)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        color: Colors.white.withOpacity(_flashOpacity),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildComboOverlay(AppTheme theme) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      right: 16,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _comboPulseController,
          builder: (context, child) {
            final scale = 1.0 + _comboPulseController.value * 0.2;
            final opacity = 0.7 + _comboPulseController.value * 0.3;
            return Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: scale,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: theme.accentColor.withOpacity(0.6)),
                  ),
                  child: Text(
                    'COMBO x$_combo 🔥',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 8),
          Text(
            'Tap the Rabbit',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTapCounter(AppTheme theme) {
    return Text(
      '$_tapsRemaining/${StorageService.miniplayTapsPerSession} taps remaining',
      style: GoogleFonts.poppins(
        fontSize: 16,
        color: Colors.white70,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  String _formatCarrots(int n) {
    final s = n.toString();
    if (s.length <= 3) return s;
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  Widget _buildCarrotBalance(AppTheme theme) {
    return Text(
      '🥕 ${_formatCarrots(_totalCarrots)} carrots',
      style: GoogleFonts.poppins(
        fontSize: 18,
        color: theme.accentColor,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildRabbitArea(AppTheme theme) {
    return SizedBox(
      height: 220,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          if (w > 0 && h > 0 && _areaWidth != w) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _areaWidth = w;
                _areaHeight = h;
                if (_rabbitOffset == Offset.zero) {
                  _rabbitOffset = Offset(
                    w / 2 - _rabbitSize / 2,
                    h / 2 - _rabbitSize / 2,
                  );
                }
              });
            }
          });
        }
        return GestureDetector(
          onTapDown: _tapsRemaining > 0 ? _onTapDown : null,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: w,
            height: h,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ..._flyingCarrots.map(
                  (c) => Positioned(
                    left: c.offsetX - 14,
                    top: c.offsetY - 14,
                    child: _FlyingCarrotWidget(
                      key: ValueKey('${c.createdAt.millisecondsSinceEpoch}_${c.offsetX}_${c.rotation}'),
                      created: c.createdAt,
                      spreadX: c.spreadX,
                      rotation: c.rotation,
                    ),
                  ),
                ),
                Positioned(
                  left: _rabbitOffset.dx,
                  top: _rabbitOffset.dy,
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: Listenable.merge([
                        _pulseAnimation,
                        _tapScaleAnimation,
                        _blinkAnimation,
                      ]),
                      builder: (context, child) {
                        final tapsUsed = 100 - _tapsRemaining;
                        double stateScale = 1.0;
                        if (tapsUsed >= 76) {
                          stateScale = 1.1;
                        } else if (tapsUsed >= 51) {
                          stateScale = 1.05;
                        }
                        final scale = _tapsRemaining > 0
                            ? _pulseAnimation.value *
                                _tapScaleAnimation.value *
                                stateScale
                            : _pulseAnimation.value * stateScale;
                        return Opacity(
                          opacity: _blinkAnimation.value,
                          child: Transform.scale(
                            scale: scale,
                            child: tapsUsed >= 76
                                ? _buildGlowRabbit(child!)
                                : child,
                          ),
                        );
                      },
                      child: Text(
                        '🐰',
                        style: const TextStyle(fontSize: _rabbitSize, height: 1),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
    );
  }

  Widget _buildGlowRabbit(Widget child) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Glow layer
        Opacity(
          opacity: 0.5,
          child: Transform.scale(
            scale: 1.15,
            child: Text(
              '🐰',
              style: TextStyle(
                fontSize: _rabbitSize,
                height: 1,
                shadows: [
                  Shadow(
                    color: Colors.amber.withOpacity(0.8),
                    blurRadius: 20,
                  ),
                  Shadow(
                    color: Colors.orange.withOpacity(0.6),
                    blurRadius: 30,
                  ),
                ],
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }

  Widget _buildNextSessionTimer(AppTheme theme) {
    final min = _minutesUntilNextSession;
    if (min == null || min <= 0) {
      return Text(
        'Session reset! Tap again.',
        style: GoogleFonts.poppins(
          fontSize: 14,
          color: Colors.white70,
        ),
      );
    }
    final hours = min ~/ 60;
    final mins = min % 60;
    final str = hours > 0 ? '${hours}h ${mins}m' : '${mins}m';
    return Text(
      'Next session in $str',
      style: GoogleFonts.poppins(
        fontSize: 14,
        color: Colors.white70,
      ),
    );
  }

}

class _FlyingCarrot {
  final DateTime createdAt;
  final double offsetX;
  final double offsetY;
  final double spreadX;
  final double rotation;
  _FlyingCarrot(this.createdAt,
      {this.offsetX = 0, this.offsetY = 0, this.spreadX = 0, this.rotation = 0});
}

class _FlyingCarrotWidget extends StatefulWidget {
  final DateTime created;
  final double spreadX;
  final double rotation;

  const _FlyingCarrotWidget({
    super.key,
    required this.created,
    this.spreadX = 0,
    this.rotation = 0,
  });

  @override
  State<_FlyingCarrotWidget> createState() => _FlyingCarrotWidgetState();
}

class _FlyingCarrotWidgetState extends State<_FlyingCarrotWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _opacity = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _offset = Tween<Offset>(
      begin: Offset.zero,
      end: Offset(widget.spreadX * 50, -1.2),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: Transform.translate(
            offset: Offset(_offset.value.dx * 60, _offset.value.dy * 80),
            child: Transform.rotate(
              angle: widget.rotation * _controller.value,
              child: const Text('🥕', style: TextStyle(fontSize: 28)),
            ),
          ),
        );
      },
    );
  }
}
