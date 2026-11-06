import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/local_app_data_service.dart';

class RequestAdminScreen extends StatefulWidget {
  const RequestAdminScreen({super.key});

  @override
  State<RequestAdminScreen> createState() => _RequestAdminScreenState();
}

class _RequestAdminScreenState extends State<RequestAdminScreen> {
  final venueController = TextEditingController();
  final addressController = TextEditingController();
  final phoneController = TextEditingController();
  final reasonController = TextEditingController();
  bool isLoading = false;

  Future<void> submitRequest() async {
    setState(() {
      isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');

      if (userId == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("User belum login")),
        );
        return;
      }

      await LocalAppDataService.saveVenueRequest(
        userId: userId,
        venueName: venueController.text,
        address: addressController.text,
        phone: phoneController.text,
        reason: reasonController.text,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pengajuan demo disimpan di perangkat.'),
          backgroundColor: Colors.green,
        ),
      );
      venueController.clear();
      addressController.clear();
      phoneController.clear();
      reasonController.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    venueController.dispose();
    addressController.dispose();
    phoneController.dispose();
    reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pengajuan Pengelola Venue"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: venueController,
              decoration: const InputDecoration(
                labelText: "Nama Venue",
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: addressController,
              decoration: const InputDecoration(
                labelText: "Alamat Venue",
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: "Nomor HP",
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: reasonController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: "Alasan Pengajuan",
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        if (venueController.text.isEmpty ||
                            phoneController.text.isEmpty ||
                            reasonController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Semua field wajib diisi"),
                            ),
                          );
                          return;
                        }
                        await submitRequest();
                      },
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text("Kirim Pengajuan"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}