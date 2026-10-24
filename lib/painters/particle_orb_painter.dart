import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Precomputed 3D Spherical Particle Model
class OrbParticle {
  final double x;
  final double y;
  final double z;
  final double theta; // Latitude angle
  final double phi;   // Azimuth angle
  final bool isPolar; // True if part of concentric polar rings

  const OrbParticle({
    required this.x,
    required this.y,
    required this.z,
    required this.theta,
    required this.phi,
    required this.isPolar,
  });
}

/// CustomPainter rendering a 3D Glowing Particle Sphere with
/// real-time audio wave deformation, depth sorting, and volumetric bloom.
class ParticleOrbPainter extends CustomPainter {
  final double time;
  final double rotY;
  final double audioLevel; // 0.0 (quiet) to 1.0 (max voice intensity)
  final bool isMuted;
  final List<OrbParticle> particles;
  final Color primaryColor;

  // Cached paint objects to avoid allocations during 60 FPS paint calls
  final Paint _particlePaint = Paint()..style = PaintingStyle.fill;
  final Paint _glowPaint = Paint();

  ParticleOrbPainter({
    required this.time,
    required this.rotY,
    required this.audioLevel,
    required this.isMuted,
    required this.particles,
    this.primaryColor = AppTheme.neonCyan,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = math.min(size.width, size.height) * 0.38;

    // 1. Draw Volumetric Core Glow
    final glowRadius = baseRadius * (1.1 + 0.25 * audioLevel);
    final coreGlowColor = isMuted
        ? AppTheme.alertAmber
        : (audioLevel > 0.05 ? primaryColor : primaryColor.withValues(alpha: 0.8));

    _glowPaint.shader = RadialGradient(
      colors: [
        coreGlowColor.withValues(alpha: 0.22 + 0.20 * audioLevel),
        coreGlowColor.withValues(alpha: 0.08 + 0.10 * audioLevel),
        Colors.transparent,
      ],
      stops: const [0.0, 0.55, 1.0],
    ).createShader(Rect.fromCircle(center: center, radius: glowRadius));

    canvas.drawCircle(center, glowRadius, _glowPaint);

    // 2. Trigonometric 3D Rotation Transform Constants
    const tiltDeg = 18.0;
    const radTilt = tiltDeg * math.pi / 180.0;
    final cosTilt = math.cos(radTilt);
    final sinTilt = math.sin(radTilt);

    final cosY = math.cos(rotY);
    final sinY = math.sin(rotY);

    // 3. Transform & Project All Particles
    final projected = <_ProjectedPoint>[];

    for (final p in particles) {
      // Harmonic Wave Deformation Math
      double dr = 0.0;
      if (isMuted) {
        // Calm resting breathing when mic is muted
        dr = 0.015 * math.sin(1.6 * time + p.theta * 2.0);
      } else if (audioLevel < 0.03) {
        // Silent Rest: Subtle quiet breathing (orb rests when user is quiet)
        dr = 0.008 * math.sin(1.8 * time + p.theta * 2.0);
      } else {
        // Voice-Reactive Displacement: Harmonic ripples and pulses scaling with volume
        final ripple = 0.22 * audioLevel * math.sin(5.0 * p.phi - 7.5 * time) * math.cos(3.5 * p.theta + 3.0 * time);
        final pulse = 0.12 * audioLevel * math.sin(8.5 * time);
        dr = ripple + pulse;
      }

      final r = (1.0 + dr) * baseRadius * (1.0 + 0.18 * audioLevel);
      final px = p.x * r;
      final py = p.y * r;
      final pz = p.z * r;

      // Rotate around Y axis
      final x1 = px * cosY + pz * sinY;
      final z1 = -px * sinY + pz * cosY;

      // Tilt forward around X axis
      final y2 = py * cosTilt - z1 * sinTilt;
      final z2 = py * sinTilt + z1 * cosTilt;

      // Normalized depth for stereoscopic attenuation (0.0 back, 1.0 front)
      final normZ = ((z2 / baseRadius) + 1.1) / 2.2;
      final clampedZ = normZ.clamp(0.0, 1.0);

      projected.add(_ProjectedPoint(
        screenX: center.dx + x1,
        screenY: center.dy + y2,
        normZ: clampedZ,
        isPolar: p.isPolar,
      ));
    }

    // 4. Depth Sorting: Render farthest particles first, nearest on top
    projected.sort((a, b) => a.normZ.compareTo(b.normZ));

    // 5. Draw 3D Spherical Particles
    for (final pt in projected) {
      final nz = pt.normZ;
      final isPol = pt.isPolar;

      // Dynamic Color & Alpha Palette
      Color pColor;
      double alpha;
      double radius;

      if (isMuted) {
        // Muted Cybernetic Amber
        alpha = isPol ? (0.65 + 0.35 * nz) : (0.25 + 0.55 * math.pow(nz, 1.4));
        pColor = Color.lerp(
          const Color(0xFFE65100),
          const Color(0xFFFFD54F),
          nz,
        )!;
        radius = (1.6 + 1.6 * nz);
      } else {
        // Electric Cyan & Cyber Green Voice Wave
        final baseAlpha = isPol ? (0.70 + 0.30 * nz) : (0.25 + 0.65 * math.pow(nz, 1.3));
        alpha = (baseAlpha * (0.85 + 0.25 * audioLevel)).clamp(0.1, 1.0);

        if (audioLevel > 0.08) {
          // Voice Reactive: Primary color blending to hot white highlights
          pColor = Color.lerp(
            primaryColor.withValues(alpha: 0.7),
            Colors.white,
            nz,
          )!;
        } else {
          // Resting Standby: Deep tone to Primary Color
          pColor = Color.lerp(
            primaryColor.withValues(alpha: 0.3),
            primaryColor,
            nz,
          )!;
        }

        radius = (1.5 + 2.2 * nz) * (1.0 + 0.35 * audioLevel);
      }

      _particlePaint.color = pColor.withValues(alpha: alpha);
      canvas.drawCircle(Offset(pt.screenX, pt.screenY), radius, _particlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant ParticleOrbPainter oldDelegate) {
    return oldDelegate.time != time ||
        oldDelegate.rotY != rotY ||
        oldDelegate.audioLevel != audioLevel ||
        oldDelegate.isMuted != isMuted;
  }
}

class _ProjectedPoint {
  final double screenX;
  final double screenY;
  final double normZ;
  final bool isPolar;

  const _ProjectedPoint({
    required this.screenX,
    required this.screenY,
    required this.normZ,
    required this.isPolar,
  });
}
