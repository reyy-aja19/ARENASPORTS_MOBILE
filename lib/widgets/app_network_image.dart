import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';

/// Gambar dari API yang mendukung PNG/JPG sekaligus SVG.
///
/// Sebagian foto lapangan pada data awal berformat SVG, sehingga
/// `Image.network` tidak dapat merendernya. Widget ini memilih perender yang
/// tepat berdasarkan ekstensi URL dan menormalkan host media lewat
/// [ApiConfig.resolveMediaUrl] agar gambar tetap tampil di emulator/perangkat.
class AppNetworkImage extends StatefulWidget {
  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Alignment alignment;
  final Color? backgroundColor;
  final Widget? placeholder;
  final Widget? errorWidget;
  final IconData fallbackIcon;
  final Color fallbackIconColor;

  const AppNetworkImage(
    this.url, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.backgroundColor,
    this.placeholder,
    this.errorWidget,
    this.fallbackIcon = Icons.image_outlined,
    this.fallbackIconColor = Colors.grey,
  });

  @override
  State<AppNetworkImage> createState() => _AppNetworkImageState();
}

class _AppNetworkImageState extends State<AppNetworkImage> {
  static final Map<String, Future<String>> _svgCache = {};

  String? _resolved;
  bool _isSvg = false;
  Future<String>? _svgFuture;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void didUpdateWidget(covariant AppNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _prepare();
    }
  }

  void _prepare() {
    _resolved = ApiConfig.resolveMediaUrl(widget.url);
    _isSvg = false;
    _svgFuture = null;

    final resolved = _resolved;
    if (resolved == null) return;

    final path = Uri.tryParse(resolved)?.path.toLowerCase() ?? '';
    if (path.endsWith('.svg')) {
      _isSvg = true;
      _svgFuture = _loadSvg(resolved);
    }
  }

  Future<String> _loadSvg(String url) {
    final cached = _svgCache[url];
    if (cached != null) return cached;

    final future = _fetchSvg(url);
    _svgCache[url] = future;
    return future;
  }

  Future<String> _fetchSvg(String url) async {
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _ImageLoadException('HTTP ${response.statusCode}');
      }
      return utf8.decode(response.bodyBytes, allowMalformed: true);
    } catch (_) {
      _svgCache.remove(url);
      rethrow;
    }
  }

  Widget _placeholder() {
    final provided = widget.placeholder;
    if (provided != null) return provided;
    return Container(
      width: widget.width,
      height: widget.height,
      color: widget.backgroundColor ?? const Color(0xFFEAF2ED),
      alignment: Alignment.center,
      child: const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Color(0xFF00A32A),
        ),
      ),
    );
  }

  Widget _fallback() {
    final provided = widget.errorWidget;
    if (provided != null) return provided;
    return Container(
      width: widget.width,
      height: widget.height,
      color: widget.backgroundColor ?? const Color(0xFFEAF2ED),
      alignment: Alignment.center,
      child: Icon(
        widget.fallbackIcon,
        color: widget.fallbackIconColor,
        size: 32,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final resolved = _resolved;
    if (resolved == null) return _fallback();

    if (_isSvg) {
      return FutureBuilder<String>(
        future: _svgFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return _placeholder();
          }

          final data = snapshot.data;
          if (snapshot.hasError || data == null || data.trim().isEmpty) {
            return _fallback();
          }

          try {
            return SvgPicture.string(
              data,
              width: widget.width,
              height: widget.height,
              fit: widget.fit,
              alignment: widget.alignment,
            );
          } catch (_) {
            return _fallback();
          }
        },
      );
    }

    return Image.network(
      resolved,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      alignment: widget.alignment,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return _placeholder();
      },
      errorBuilder: (context, error, stackTrace) => _fallback(),
    );
  }
}

class _ImageLoadException implements Exception {
  const _ImageLoadException(this.message);

  final String message;

  @override
  String toString() => message;
}
