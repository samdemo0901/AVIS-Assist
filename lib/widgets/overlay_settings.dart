enum OverlayPosition { top, center, bottom }
enum OverlayAnimation { slide, fade, scale }

class OverlayConfig {
  int autoHideSeconds; // 5, 8, 12, or 0 (disabled)
  double heightFactor; // 0.5 (Compact), 0.65 (Medium), 0.8 (Large)
  OverlayPosition position;
  OverlayAnimation animationStyle;

  OverlayConfig({
    this.autoHideSeconds = 8,
    this.heightFactor = 0.65,
    this.position = OverlayPosition.bottom,
    this.animationStyle = OverlayAnimation.slide,
  });

  String get positionName {
    switch (position) {
      case OverlayPosition.top:
        return 'Top Floating';
      case OverlayPosition.center:
        return 'Centered Screen';
      case OverlayPosition.bottom:
        return 'Bottom Sheet';
    }
  }

  String get animationName {
    switch (animationStyle) {
      case OverlayAnimation.slide:
        return 'Slide Up / Down';
      case OverlayAnimation.fade:
        return 'Fade In / Out';
      case OverlayAnimation.scale:
        return 'Scale & Pop';
    }
  }

  String get sizeName {
    if (heightFactor <= 0.55) return 'Compact (50%)';
    if (heightFactor >= 0.75) return 'Large (80%)';
    return 'Medium (65%)';
  }
}

class OverlaySettings {
  OverlayConfig sandboxConfig;

  OverlaySettings({
    OverlayConfig? sandboxConfig,
  }) : sandboxConfig = sandboxConfig ?? OverlayConfig(heightFactor: 0.75, autoHideSeconds: 12);

  int get autoHideSeconds => sandboxConfig.autoHideSeconds;
  double get heightFactor => sandboxConfig.heightFactor;
  OverlayPosition get position => sandboxConfig.position;
  OverlayAnimation get animationStyle => sandboxConfig.animationStyle;
}
