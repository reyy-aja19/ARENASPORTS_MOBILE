import 'package:flutter/material.dart';

import '../widgets/point_center.dart';

class PointScreen extends StatelessWidget {
  const PointScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          "Poin Saya",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: const SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: PointCenter(),
        ),
      ),
    );
  }
}
