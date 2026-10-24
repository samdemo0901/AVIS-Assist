import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../painters/particle_orb_painter.dart';

/// Interactive 3D Neural Particle Orb Widget
/// Handles 60 FPS animation ticker, touch rotation, audio smoothing, and sound telemetry.
class NeuralOrbWidget extends StatefulWidget {
  final Stream<double>? audioLevelStream;
  final bool isMuted;
  final VoidCallback onToggleMute;
  final VoidCallback? onDoubleTap;
  final Color? primaryColor;

  const NeuralOrbWidget({
    super.key,
    this.audioLevelStream,
    required this.isMuted,
    required this.onToggleMute,
    this.onDoubleTap,
    this.primaryColor,
  });

  @override
  State<NeuralOrbWidget> createState() => _NeuralOrbWidgetState();
}

class _NeuralOrbWidgetState extends State<NeuralOrbWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ticker;
  late final List<OrbParticle> _particles;
  StreamSubscription<double>? _audioSub;

  double _time = 0.0;
  double _rotY = 0.0;
  double _audioLevel = 0.0;
  double _targetAudioLevel = 0.0;

  @override
  void initState() {
    super.initState();
    _particles = _generateSphereParticles();

    // 60 FPS animation ticker
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..addListener(_onTick)..repeat();

    _subscribeToAudioStream();
  }

  void _subscribeToAudioStream() {
    _audioSub?.cancel();
    _audioSub = widget.audioLevelStream?.listen((level) {
      if (mounted) {
        setState(() {
          _targetAudioLevel = level.clamp(0.0, 1.0);
        });
      }
    });
  }

  @override
  void didUpdateWidget(NeuralOrbWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audioLevelStream != widget.audioLevelStream) {
      _subscribeToAudioStream();
    }
  }

  void _onTick() {
    const dt = 0.016;
    _time += dt;

    // Smooth Exponential Attack & Decay filter for audio volume
    if (_targetAudioLevel > _audioLevel) {
      _audioLevel += (_targetAudioLevel - _audioLevel) * 0.45; // Fast attack
    } else {
      _audioLevel += (_targetAudioLevel - _audioLevel) * 0.18; // Gentle decay
    }
    if (_audioLevel < 0.005) _audioLevel = 0.0;

    // Dynamic rotation: calm at rest, accelerates with speech
    final speed = widget.isMuted
        ? 0.35
        : (_audioLevel > 0.03 ? (0.45 + 1.2 * _audioLevel) : 0.40);
    _rotY = (_rotY + speed * dt) % (2 * math.pi);

    setState(() {});
  }

  List<OrbParticle> _generateSphereParticles() {
    final list = <OrbParticle>[];

    // 1. Concentric rings at both poles
    final polarRadii = [0.06, 0.14, 0.24, 0.35];
    for (final r in polarRadii) {
      final nRing = (r * 180).toInt() + 14;
      for (final sign in [1.0, -1.0]) {
        final y = sign * math.sqrt(math.max(0.01, 1.0 - r * r));
        for (int i = 0; i < nRing; i++) {
          final angle = 2.0 * math.pi * i / nRing;
          final x = r * math.cos(angle);
          final z = r * math.sin(angle);
          final theta = math.asin(y.clamp(-1.0, 1.0));
          final phi = math.atan2(z, x);
          list.add(OrbParticle(
            x: x,
            y: y,
            z: z,
            theta: theta,
            phi: phi,
            isPolar: true,
          ));
        }
      }
    }

    // 2. Body latitude and longitude bands
    const nLat = 38;
    for (int i = 1; i < nLat; i++) {
      final lat = -math.pi / 2.0 + math.pi * i / nLat;
      final y = math.sin(lat);
      final rLat = math.cos(lat);
      final nLon = (rLat * 70).toInt() + 8;
      for (int j = 0; j < nLon; j++) {
        final lon = 2.0 * math.pi * j / nLon;
        final x = rLat * math.cos(lon);
        final z = rLat * math.sin(lon);
        final theta = lat;
        final phi = lon;
        list.add(OrbParticle(
          x: x,
          y: y,
          z: z,
          theta: theta,
          phi: phi,
          isPolar: false,
        ));
      }
    }

    return list;
  }

  @override
  void dispose() {
    _audioSub?.cancel();
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Dynamically compute orb dimension bounded by viewport constraints
        final maxAvail = math.min(
          constraints.maxWidth > 0 ? constraints.maxWidth * 0.85 : 320.0,
          constraints.maxHeight > 80 ? constraints.maxHeight - 60 : 320.0,
        );
        final orbDimension = maxAvail.clamp(220.0, 380.0);

        return Center(
          child: GestureDetector(
            onTap: widget.onToggleMute,
            onDoubleTap: widget.onDoubleTap,
            onPanUpdate: (details) {
              setState(() {
                _rotY += details.delta.dx * 0.01;
              });
            },
            child: RepaintBoundary(
              child: SizedBox(
                width: orbDimension,
                height: orbDimension,
                child: CustomPaint(
                  painter: ParticleOrbPainter(
                    time: _time,
                    rotY: _rotY,
                    audioLevel: _audioLevel,
                    isMuted: widget.isMuted,
                    particles: _particles,
                    primaryColor: widget.primaryColor ?? const Color(0xFF00E5FF),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
