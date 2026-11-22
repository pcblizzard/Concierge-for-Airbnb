import 'dart:async';
import 'package:camera/camera.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Wake-on-Approach über Frontkamera (Bewegungserkennung per Helligkeitsdifferenz,
/// keine Bildspeicherung, keine Übertragung) + Nachtdimmung.
class DisplayService {
  CameraController? _cam;
  List<int>? _prev;
  Timer? _idle;
  DateTime _lastFrame = DateTime.fromMillisecondsSinceEpoch(0);
  bool awake = true;

  static bool isNight([DateTime? t]) {
    final h = (t ?? DateTime.now()).hour;
    return h >= 22 || h < 7;
  }

  double get _activeBrightness => isNight() ? 0.08 : 0.8;

  Future<void> start() async {
    await WakelockPlus.enable();
    _wake();
    final cams = await availableCameras();
    final front = cams.firstWhere((c) => c.lensDirection == CameraLensDirection.front, orElse: () => cams.first);
    _cam = CameraController(front, ResolutionPreset.low, enableAudio: false);
    await _cam!.initialize();
    await _cam!.startImageStream(_onFrame);
  }

  void _onFrame(CameraImage img) {
    final now = DateTime.now();
    if (now.difference(_lastFrame) < const Duration(milliseconds: 500)) return;
    _lastFrame = now;
    final y = img.planes[0].bytes;
    final step = y.length ~/ 400;
    final sample = [for (var i = 0; i < y.length; i += step) y[i]];
    if (_prev != null) {
      var diff = 0;
      for (var i = 0; i < sample.length && i < _prev!.length; i++) {
        diff += (sample[i] - _prev![i]).abs();
      }
      if (diff / sample.length > 12) _wake();
    }
    _prev = sample;
  }

  void _wake() {
    awake = true;
    ScreenBrightness().setApplicationScreenBrightness(_activeBrightness);
    _idle?.cancel();
    _idle = Timer(const Duration(minutes: 2), () {
      awake = false;
      ScreenBrightness().setApplicationScreenBrightness(0.01);
    });
  }

  /// Bei Touch aufrufen.
  void touch() => _wake();

  Future<void> dispose() async {
    _idle?.cancel();
    await _cam?.dispose();
  }
}
