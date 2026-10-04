import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

/// The trained elbow-rep autoencoder (Inteli_Rehab_AI_Pipeline/notebooks/train_elbow_model.ipynb),
/// run in plain Dart so the app needs no ML runtime and works offline.
///
/// A rep is the elbow angle resampled to [steps] points plus log(duration) repeated on every
/// step. The network squeezes it to a handful of numbers and rebuilds it; the mean squared
/// rebuild error (in normalised units) is the score. A healthy rep rebuilds well.
///
/// The weights come from assets/ai/elbow_autoencoder.json, written by
/// Inteli_Rehab_AI_Pipeline/src/elbow/export_to_app.py. test/elbow_model_test.dart checks this
/// code against PyTorch's own numbers, so the two cannot drift apart.
class ElbowAutoencoder {
  final int steps;
  final bool withDuration;
  final List<double> mean;
  final List<double> std;
  final double thresholdGentle;
  final double thresholdBalanced;

  /// Allowed deviation (degrees) from the rebuilt curve at each step.
  final List<double> tolerance;

  /// A healthy rep's length in seconds (low, high).
  final (double, double) healthyDuration;

  final Map<String, _Tensor> _w;

  ElbowAutoencoder._({
    required this.steps,
    required this.withDuration,
    required this.mean,
    required this.std,
    required this.thresholdGentle,
    required this.thresholdBalanced,
    required this.tolerance,
    required this.healthyDuration,
    required Map<String, _Tensor> weights,
  }) : _w = weights;

  int get channels => withDuration ? 2 : 1;

  /// Parses the exported JSON. Throws [FormatException] if it is not a model this code can run.
  factory ElbowAutoencoder.fromJson(String source) {
    final Map<String, dynamic> j;
    try {
      j = jsonDecode(source) as Map<String, dynamic>;
    } catch (_) {
      throw const FormatException('Elbow model file is not valid JSON.');
    }
    if (j['format'] != 1) throw const FormatException('Unsupported elbow model format.');

    List<double> doubles(String key) => [for (final v in j[key] as List) (v as num).toDouble()];

    final weights = <String, _Tensor>{};
    (j['tensors'] as Map<String, dynamic>).forEach((name, raw) {
      final m = raw as Map<String, dynamic>;
      final shape = [for (final d in m['shape'] as List) d as int];
      final bytes = base64Decode(m['data'] as String);
      final data = bytes.buffer.asByteData(bytes.offsetInBytes, bytes.lengthInBytes);
      final n = shape.fold<int>(1, (a, b) => a * b);
      if (bytes.lengthInBytes != n * 4) throw FormatException('Weights for $name have the wrong size.');
      final values = Float64List(n);
      for (var i = 0; i < n; i++) {
        values[i] = data.getFloat32(i * 4, Endian.little);
      }
      weights[name] = _Tensor(shape, values);
    });

    final model = ElbowAutoencoder._(
      steps: j['steps'] as int,
      withDuration: j['with_duration'] as bool,
      mean: doubles('mean'),
      std: doubles('std'),
      thresholdGentle: (j['threshold_gentle'] as num).toDouble(),
      thresholdBalanced: (j['threshold_balanced'] as num).toDouble(),
      tolerance: doubles('tolerance'),
      healthyDuration: (
        (j['healthy_duration_range'] as List)[0].toDouble() as double,
        (j['healthy_duration_range'] as List)[1].toDouble() as double,
      ),
      weights: weights,
    );
    model._validate();
    return model;
  }

  void _validate() {
    const need = [
      'encoder.0.weight', 'encoder.0.bias', 'encoder.2.weight', 'encoder.2.bias', 'encoder.4.weight',
      'encoder.4.bias', 'encoder.7.weight', 'encoder.7.bias', 'decoder_input.weight', 'decoder_input.bias',
      'decoder.0.weight', 'decoder.0.bias', 'decoder.2.weight', 'decoder.2.bias', 'decoder.4.weight',
      'decoder.4.bias',
    ];
    for (final k in need) {
      if (!_w.containsKey(k)) throw FormatException('Elbow model is missing "$k".');
    }
    if (steps != 100) throw const FormatException('This code runs 100-step reps only.');
    if (mean.length != channels || std.length != channels || tolerance.length != steps) {
      throw const FormatException('Elbow model normalisation does not match its shape.');
    }
    if (_w['encoder.0.weight']!.shape[1] != channels) {
      throw const FormatException('Elbow model channel count does not match its weights.');
    }
  }

  /// Scores one rep. [angle] is [steps] elbow angles in degrees, [durationSeconds] how long it took.
  ElbowScore score(List<double> angle, double durationSeconds) {
    if (angle.length != steps) throw ArgumentError('A rep must have $steps points, got ${angle.length}.');
    if (!(durationSeconds > 0) || !durationSeconds.isFinite) throw ArgumentError('Duration must be positive.');

    // Input, normalised per channel: channel 0 = angle, channel 1 = log(duration) on every step.
    final x = List<Float64List>.generate(channels, (_) => Float64List(steps));
    for (var i = 0; i < steps; i++) {
      x[0][i] = (angle[i] - mean[0]) / std[0];
    }
    if (withDuration) {
      final d = (math.log(durationSeconds) - mean[1]) / std[1];
      for (var i = 0; i < steps; i++) {
        x[1][i] = d;
      }
    }

    // Encoder: three stride-2 convolutions (100 -> 50 -> 25 -> 13), then a linear layer to the code.
    var h = _relu(_conv1d(x, _w['encoder.0.weight']!, _w['encoder.0.bias']!));
    h = _relu(_conv1d(h, _w['encoder.2.weight']!, _w['encoder.2.bias']!));
    h = _relu(_conv1d(h, _w['encoder.4.weight']!, _w['encoder.4.bias']!));
    final flat = Float64List(h.length * h[0].length);
    var k = 0;
    for (final row in h) {
      for (final v in row) {
        flat[k++] = v;
      }
    }
    final code = _linear(flat, _w['encoder.7.weight']!, _w['encoder.7.bias']!);

    // Decoder: linear back to 64 x 13, then three transposed convolutions (13 -> 25 -> 50 -> 100).
    final up = _linear(code, _w['decoder_input.weight']!, _w['decoder_input.bias']!);
    final width = up.length ~/ 64;
    var g = List<Float64List>.generate(64, (c) => Float64List.sublistView(up, c * width, (c + 1) * width));
    g = _relu(_convTranspose1d(g, _w['decoder.0.weight']!, _w['decoder.0.bias']!, outputPadding: 0));
    g = _relu(_convTranspose1d(g, _w['decoder.2.weight']!, _w['decoder.2.bias']!, outputPadding: 1));
    final out = _convTranspose1d(g, _w['decoder.4.weight']!, _w['decoder.4.bias']!, outputPadding: 1);

    // Score = mean squared rebuild error over every channel and step (normalised units).
    var sum = 0.0;
    for (var c = 0; c < channels; c++) {
      for (var i = 0; i < steps; i++) {
        final e = out[c][i] - x[c][i];
        sum += e * e;
      }
    }
    final rebuilt = [for (var i = 0; i < steps; i++) out[0][i] * std[0] + mean[0]];
    return ElbowScore(score: sum / (channels * steps), rebuiltDegrees: rebuilt);
  }

  // ---- the layers --------------------------------------------------------------------------

  /// Conv1d(kernel 5, stride 2, padding 2). Weight shape (out, in, 5).
  static List<Float64List> _conv1d(List<Float64List> x, _Tensor w, _Tensor b) {
    final outCh = w.shape[0], inCh = w.shape[1], kernel = w.shape[2];
    const stride = 2, pad = 2;
    final len = x[0].length;
    final outLen = (len + 2 * pad - kernel) ~/ stride + 1;
    final out = List<Float64List>.generate(outCh, (_) => Float64List(outLen));
    for (var o = 0; o < outCh; o++) {
      for (var i = 0; i < outLen; i++) {
        var acc = b.v[o];
        final start = i * stride - pad;
        for (var c = 0; c < inCh; c++) {
          final base = (o * inCh + c) * kernel;
          final row = x[c];
          for (var k = 0; k < kernel; k++) {
            final p = start + k;
            if (p >= 0 && p < len) acc += w.v[base + k] * row[p];
          }
        }
        out[o][i] = acc;
      }
    }
    return out;
  }

  /// ConvTranspose1d(kernel 5, stride 2, padding 2, output_padding). Weight shape (in, out, 5).
  static List<Float64List> _convTranspose1d(List<Float64List> x, _Tensor w, _Tensor b, {required int outputPadding}) {
    final inCh = w.shape[0], outCh = w.shape[1], kernel = w.shape[2];
    const stride = 2, pad = 2;
    final len = x[0].length;
    final outLen = (len - 1) * stride - 2 * pad + (kernel - 1) + outputPadding + 1;
    final out = List<Float64List>.generate(outCh, (o) => Float64List(outLen)..fillRange(0, outLen, b.v[o]));
    for (var c = 0; c < inCh; c++) {
      final row = x[c];
      for (var i = 0; i < len; i++) {
        final xv = row[i];
        for (var o = 0; o < outCh; o++) {
          final base = (c * outCh + o) * kernel;
          for (var k = 0; k < kernel; k++) {
            final p = i * stride - pad + k;
            if (p >= 0 && p < outLen) out[o][p] += xv * w.v[base + k];
          }
        }
      }
    }
    return out;
  }

  /// Linear layer. Weight shape (out, in).
  static Float64List _linear(Float64List x, _Tensor w, _Tensor b) {
    final outN = w.shape[0], inN = w.shape[1];
    if (x.length != inN) throw StateError('Linear layer expected $inN inputs, got ${x.length}.');
    final out = Float64List(outN);
    for (var o = 0; o < outN; o++) {
      var acc = b.v[o];
      final base = o * inN;
      for (var i = 0; i < inN; i++) {
        acc += w.v[base + i] * x[i];
      }
      out[o] = acc;
    }
    return out;
  }

  static List<Float64List> _relu(List<Float64List> x) {
    for (final row in x) {
      for (var i = 0; i < row.length; i++) {
        if (row[i] < 0) row[i] = 0;
      }
    }
    return x;
  }
}

class ElbowScore {
  /// Mean squared rebuild error in normalised units: higher = less like a healthy rep.
  final double score;

  /// What the rep "should" have looked like, in degrees, at each of the 100 steps.
  final List<double> rebuiltDegrees;

  const ElbowScore({required this.score, required this.rebuiltDegrees});
}

class _Tensor {
  final List<int> shape;
  final Float64List v;
  const _Tensor(this.shape, this.v);
}
