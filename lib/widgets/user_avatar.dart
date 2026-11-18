import 'package:flutter/material.dart';

import '../config/api_config.dart';
import 'app_network_image.dart';

/// Avatar pengguna yang tetap tampil meskipun foto belum ada atau gagal dimuat.
///
/// - Belum punya foto: menampilkan inisial nama.
/// - Foto sedang dimuat / gagal dimuat / URL tidak valid: inisial nama.
/// - Mendukung JPG, PNG, WEBP, maupun SVG melalui [AppNetworkImage].
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    this.url,
    required this.radius,
    this.initials = 'U',
    this.onTap,
    this.backgroundColor = const Color(0xFFE8F8ED),
    this.foregroundColor = const Color(0xFF00A32A),
    this.borderColor,
    this.borderWidth = 2,
  });

  final String? url;
  final double radius;
  final String initials;
  final VoidCallback? onTap;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color? borderColor;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;
    final resolved = ApiConfig.resolveMediaUrl(url);
    final label = initials.trim().isEmpty ? 'U' : initials.trim().toUpperCase();

    Widget initialsAvatar() {
      return Container(
        width: size,
        height: size,
        color: backgroundColor,
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: EdgeInsets.all(radius * 0.2),
            child: Text(
              label,
              style: TextStyle(
                fontSize: radius * 0.8,
                fontWeight: FontWeight.bold,
                color: foregroundColor,
              ),
            ),
          ),
        ),
      );
    }

    Widget content;
    if (resolved == null) {
      content = initialsAvatar();
    } else {
      content = AppNetworkImage(
        resolved,
        width: size,
        height: size,
        fit: BoxFit.cover,
        backgroundColor: backgroundColor,
        placeholder: initialsAvatar(),
        errorWidget: initialsAvatar(),
        fallbackIcon: Icons.person_rounded,
        fallbackIconColor: foregroundColor,
      );
    }

    Widget avatar = ClipOval(
      child: SizedBox(width: size, height: size, child: content),
    );

    if (borderColor != null) {
      avatar = Container(
        padding: EdgeInsets.all(borderWidth),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: borderColor!, width: borderWidth),
        ),
        child: avatar,
      );
    }

    if (onTap == null) return avatar;

    return Semantics(
      button: true,
      label: 'Lihat foto profil',
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: avatar,
      ),
    );
  }
}
