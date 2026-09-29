import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

import '../../../core/theme/app_theme.dart';

/// The Home dashboard's 3D anatomical arm model (assets/models/arm_anatomy.glb)
/// — a real glTF model rather than the flat 2D joint painter this replaces.
/// Static/reference, not driven by session data (that's still the Active
/// Session screen's live, colour-coded twin) — the patient can rotate and
/// zoom it, but it doesn't move on its own beyond a slow idle auto-rotate.
///
/// Fully offline: on Android/iOS, model_viewer_plus serves both the
/// `<model-viewer>` JS and the .glb from bundled Flutter assets, never a
/// CDN — no different from any other asset-backed widget here (Rule 26).
class ArmModelViewer extends StatelessWidget {
  final double height;
  const ArmModelViewer({super.key, this.height = 220});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      image: true,
      label: '3D anatomical model of an arm. Drag to rotate, pinch to zoom.',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: height,
          child: ModelViewer(
            backgroundColor: c.surface,
            src: 'assets/models/arm_anatomy.glb',
            alt: '3D anatomical model of an arm',
            autoRotate: true,
            autoRotateDelay: 1200,
            rotationPerSecond: '18deg',
            cameraControls: true,
            disableZoom: false,
            ar: false,
            loading: Loading.lazy,
          ),
        ),
      ),
    );
  }
}
