import 'package:flutter/material.dart';

/// Navigator global agar layar kunci (yang berada di atas Navigator) tetap
/// dapat mengarahkan pengguna ke halaman login setelah logout.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
