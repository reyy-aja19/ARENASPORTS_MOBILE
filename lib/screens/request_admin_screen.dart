import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_client.dart';
import '../services/api_service.dart';

/// Pengajuan pengelola venue sesuai alur web (`/venue-application`).
class RequestAdminScreen extends StatefulWidget {
  const RequestAdminScreen({super.key});

  @override
  State<RequestAdminScreen> createState() => _RequestAdminScreenState();
}

class _RequestAdminScreenState extends State<RequestAdminScreen> {
  static const List<String> _sportOptions = [
    'Badminton',
    'Futsal',
    'Basketball',
    'Tenis',
    'Mini Soccer',
  ];

  static const Map<String, String> _documentLabels = {
    'identity_document': 'Identitas Pemohon',
    'ownership_document': 'Bukti Kepemilikan',
    'lease_document': 'Perjanjian Sewa',
    'authorization_document': 'Surat Kuasa/Penunjukan',
    'business_license': 'NIB atau Izin Usaha',
    'venue_exterior_photo': 'Foto Tampak Depan',
    'venue_interior_photo': 'Foto Bagian Dalam',
  };

  final _applicantPhone = TextEditingController();
  final _identityNumber = TextEditingController();
  final _ownerAddress = TextEditingController();
  final _companyName = TextEditingController();
  final _businessType = TextEditingController();
  final _nib = TextEditingController();
  final _companyAddress = TextEditingController();
  final _city = TextEditingController();
  final _province = TextEditingController();
  final _companyPhone = TextEditingController();
  final _companyDescription = TextEditingController();
  final _venueName = TextEditingController();
  final _address = TextEditingController();
  final _contactPhone = TextEditingController();
  final _description = TextEditingController();
  final _googleMapsUrl = TextEditingController();
  final _operatingHours = TextEditingController(text: '08:00 - 22:00');
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  final _facilities = TextEditingController();

  final ImagePicker _picker = ImagePicker();

  final Set<String> _sports = {};
  final Map<String, String> _documents = {};
  final List<String> _courtPhotos = [];
  final Set<String> _existingDocumentTypes = {};

  String _relationship = 'owner';
  String _ownershipType = 'Milik Sendiri';
  bool _acceptedTerms = false;

  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _canSubmit = true;
  String? _error;
  Map<String, dynamic>? _application;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in [
      _applicantPhone,
      _identityNumber,
      _ownerAddress,
      _companyName,
      _businessType,
      _nib,
      _companyAddress,
      _city,
      _province,
      _companyPhone,
      _companyDescription,
      _venueName,
      _address,
      _contactPhone,
      _description,
      _googleMapsUrl,
      _operatingHours,
      _latitude,
      _longitude,
      _facilities,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await ApiService.instance.venueApplication();
      if (!mounted) return;

      final application = data['application'] is Map
          ? Map<String, dynamic>.from(data['application'] as Map)
          : null;

      setState(() {
        _application = application;
        _canSubmit = data['can_submit'] != false;
        _existingDocumentTypes
          ..clear()
          ..addAll(_documentTypesFrom(application));
        _prefill(application);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Gagal memuat pengajuan: $e';
        _isLoading = false;
      });
    }
  }

  List<String> _documentTypesFrom(Map<String, dynamic>? application) {
    if (application == null) return const [];
    final documents = application['documents'];
    if (documents is! List) return const [];
    return documents
        .whereType<Map>()
        .map((item) => item['document_type']?.toString() ?? '')
        .where((value) => value.isNotEmpty)
        .toList();
  }

  void _prefill(Map<String, dynamic>? application) {
    if (application == null) return;

    String text(String key) => application[key]?.toString() ?? '';

    _venueName.text = text('venue_name');
    _address.text = text('address');
    _contactPhone.text = text('contact_phone');
    _description.text = text('description');
    _googleMapsUrl.text = text('google_maps_url');
    _operatingHours.text = text('operating_hours');
    _city.text = text('city');
    _province.text = text('province');
    _companyName.text = text('company_name');
    _businessType.text = text('business_type');
    _applicantPhone.text = text('applicant_phone');

    final relationship = text('applicant_relationship');
    if (['owner', 'manager', 'representative'].contains(relationship)) {
      _relationship = relationship;
    }

    final ownership = text('ownership_type');
    if (['Milik Sendiri', 'Sewa'].contains(ownership)) {
      _ownershipType = ownership;
    }

    final sports = application['sports'];
    if (sports is List) {
      _sports
        ..clear()
        ..addAll(sports.map((item) => item.toString()));
    }

    final facilities = application['facilities'];
    if (facilities is List) {
      _facilities.text = facilities.map((item) => item.toString()).join(', ');
    }
  }

  String _messageFor(Object error) {
    if (error is ApiException) return error.message;
    return 'Terjadi kesalahan: $error';
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<String?> _pickImage({bool useCamera = false}) async {
    try {
      final file = await _picker.pickImage(
        source: useCamera ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
      );
      return file?.path;
    } catch (e) {
      if (mounted) {
        _showSnackBar('Gagal memilih file: $e', Colors.red);
      }
      return null;
    }
  }

  Future<void> _chooseDocument(String key) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Pilih dari galeri'),
                onTap: () => Navigator.pop(context, 'gallery'),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Ambil foto'),
                onTap: () => Navigator.pop(context, 'camera'),
              ),
            ],
          ),
        );
      },
    );

    if (choice == null || !mounted) return;

    final path = await _pickImage(useCamera: choice == 'camera');
    if (path == null || !mounted) return;

    setState(() => _documents[key] = path);
  }

  Future<void> _addCourtPhotos() async {
    if (_courtPhotos.length >= 8) {
      _showSnackBar('Maksimal 8 foto lapangan.', Colors.orange);
      return;
    }

    final path = await _pickImage();
    if (path == null || !mounted) return;

    setState(() => _courtPhotos.add(path));
  }

  Future<void> _submit() async {
    final validation = _validate();
    if (validation != null) {
      _showSnackBar(validation, Colors.red);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final fields = <String, dynamic>{
        'applicant_phone': _applicantPhone.text.trim(),
        'applicant_relationship': _relationship,
        if (_identityNumber.text.trim().isNotEmpty)
          'identity_number': _identityNumber.text.trim(),
        'owner_address': _ownerAddress.text.trim(),
        'accepted_terms': _acceptedTerms,
        'company_name': _companyName.text.trim(),
        'business_type': _businessType.text.trim(),
        if (_nib.text.trim().isNotEmpty) 'nib': _nib.text.trim(),
        'company_address': _companyAddress.text.trim(),
        'city': _city.text.trim(),
        'province': _province.text.trim(),
        'company_phone': _companyPhone.text.trim(),
        if (_companyDescription.text.trim().isNotEmpty)
          'company_description': _companyDescription.text.trim(),
        'venue_name': _venueName.text.trim(),
        'address': _address.text.trim(),
        'contact_phone': _contactPhone.text.trim(),
        'description': _description.text.trim(),
        'sports': _sports.toList(),
        'ownership_type': _ownershipType,
        if (_googleMapsUrl.text.trim().isNotEmpty)
          'google_maps_url': _googleMapsUrl.text.trim(),
        'operating_hours': _operatingHours.text.trim(),
        if (_latitude.text.trim().isNotEmpty) 'latitude': _latitude.text.trim(),
        if (_longitude.text.trim().isNotEmpty)
          'longitude': _longitude.text.trim(),
        'facilities': _facilitiesList(),
      };

      await ApiService.instance.submitVenueApplication(
        fields: fields,
        documentPaths: Map<String, String>.from(_documents),
        courtPhotos: List<String>.from(_courtPhotos),
      );

      if (!mounted) return;
      _showSnackBar(
        'Pengajuan venue berhasil dikirim dan menunggu verifikasi Superadmin.',
        const Color(0xFF00A32A),
      );
      _clearDraft();
      await _load();
    } catch (e) {
      if (mounted) _showSnackBar(_messageFor(e), Colors.red);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  List<String> _facilitiesList() {
    return _facilities.text
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  bool _hasDocument(String type) => _existingDocumentTypes.contains(type);

  String? _validate() {
    bool empty(TextEditingController controller) =>
        controller.text.trim().isEmpty;

    if (empty(_applicantPhone)) return 'Nomor HP pemohon wajib diisi.';
    if (empty(_ownerAddress)) return 'Alamat pemohon wajib diisi.';
    if (empty(_companyName)) return 'Nama badan usaha wajib diisi.';
    if (empty(_businessType)) return 'Jenis usaha wajib diisi.';
    if (empty(_companyAddress)) return 'Alamat usaha wajib diisi.';
    if (empty(_city)) return 'Kota wajib diisi.';
    if (empty(_province)) return 'Provinsi wajib diisi.';
    if (empty(_companyPhone)) return 'Nomor telepon usaha wajib diisi.';
    if (empty(_venueName)) return 'Nama venue wajib diisi.';
    if (empty(_address)) return 'Alamat venue wajib diisi.';
    if (empty(_contactPhone)) return 'Nomor kontak venue wajib diisi.';
    if (empty(_description)) return 'Deskripsi venue wajib diisi.';
    if (_sports.isEmpty) return 'Pilih minimal satu cabang olahraga.';
    if (empty(_operatingHours)) return 'Jam operasional wajib diisi.';
    if (!_acceptedTerms) {
      return 'Kamu harus menyetujui pernyataan tanggung jawab.';
    }

    if (!_hasDocument('Identitas Pemohon') &&
        !_documents.containsKey('identity_document')) {
      return 'Lampirkan identitas pemohon.';
    }

    final ownershipDocument = _ownershipType == 'Sewa'
        ? 'lease_document'
        : 'ownership_document';
    final ownershipLabel = _ownershipType == 'Sewa'
        ? 'Perjanjian Sewa'
        : 'Bukti Kepemilikan';
    if (!_hasDocument(ownershipLabel) &&
        !_documents.containsKey(ownershipDocument)) {
      return 'Lampirkan $ownershipLabel.';
    }

    final needsAuthorization =
        _relationship == 'manager' || _relationship == 'representative';
    if (needsAuthorization &&
        !_hasDocument('Surat Kuasa/Penunjukan') &&
        !_documents.containsKey('authorization_document')) {
      return 'Lampirkan surat kuasa atau penunjukan.';
    }

    if (!_hasDocument('Foto Tampak Depan') &&
        !_documents.containsKey('venue_exterior_photo')) {
      return 'Lampirkan foto tampak depan venue.';
    }
    if (!_hasDocument('Foto Bagian Dalam') &&
        !_documents.containsKey('venue_interior_photo')) {
      return 'Lampirkan foto bagian dalam venue.';
    }
    if (!_hasDocument('Foto Fasilitas Lapangan') && _courtPhotos.isEmpty) {
      return 'Lampirkan minimal satu foto fasilitas lapangan.';
    }

    return null;
  }

  void _clearDraft() {
    _identityNumber.clear();
    _ownerAddress.clear();
    _nib.clear();
    _companyAddress.clear();
    _companyPhone.clear();
    _companyDescription.clear();
    _documents.clear();
    _courtPhotos.clear();
    _acceptedTerms = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Pengajuan Pengelola Venue'),
        backgroundColor: Colors.white,
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF00A32A)),
      );
    }

    if (_error != null && _application == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 56, color: Colors.grey),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    if (!_canSubmit) {
      return _buildStatusView();
    }

    return _buildForm();
  }

  Widget _buildStatusView() {
    final application = _application ?? const <String, dynamic>{};
    final status = application['status']?.toString() ?? 'pending';
    final note = application['admin_note']?.toString();
    final histories = application['histories'];
    final documents = application['documents'];

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.storefront_outlined,
                      color: Color(0xFF00A32A),
                      size: 28,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        application['venue_name']?.toString() ??
                            'Pengajuan Venue',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    _statusBadge(status),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _statusMessage(status),
                  style: TextStyle(color: Colors.grey.shade700, height: 1.5),
                ),
                if (note != null && note.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF4E5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Catatan Superadmin',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(note),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (documents is List && documents.isNotEmpty) ...[
            const SizedBox(height: 18),
            _sectionCard(
              title: 'Dokumen Terunggah',
              children: documents.whereType<Map>().map((document) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.description_outlined,
                    color: Color(0xFF00A32A),
                  ),
                  title: Text(document['document_type']?.toString() ?? '-'),
                  subtitle: Text(document['original_name']?.toString() ?? ''),
                );
              }).toList(),
            ),
          ],
          if (histories is List && histories.isNotEmpty) ...[
            const SizedBox(height: 18),
            _sectionCard(
              title: 'Riwayat Pengajuan',
              children: histories.whereType<Map>().map((history) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.history, color: Color(0xFF00A32A)),
                  title: Text(
                    '${_statusLabel(history['from_status']?.toString())} → '
                    '${_statusLabel(history['to_status']?.toString())}',
                  ),
                  subtitle: Text(history['note']?.toString() ?? ''),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Muat Ulang Status'),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    final isRevision =
        _application?['status']?.toString().toLowerCase() == 'revision' ||
        _application?['status']?.toString() == 'Perlu Revisi';

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (isRevision)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4E5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pengajuan perlu diperbaiki',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  'Perbarui data atau dokumen sesuai catatan Superadmin, lalu kirim ulang.',
                ),
              ],
            ),
          ),
        _sectionCard(
          title: 'Data Pemohon',
          children: [
            _textField(
              _applicantPhone,
              'Nomor HP/WhatsApp Pemohon',
              keyboardType: TextInputType.phone,
              required: true,
            ),
            _dropdownField<String>(
              label: 'Hubungan dengan Usaha',
              value: _relationship,
              items: const {
                'owner': 'Pemilik',
                'manager': 'Pengelola',
                'representative': 'Perwakilan',
              },
              onChanged: (value) => setState(() => _relationship = value!),
            ),
            _textField(_identityNumber, 'Nomor Identitas (opsional)'),
            _textField(
              _ownerAddress,
              'Alamat Pemohon',
              maxLines: 2,
              required: true,
            ),
          ],
        ),
        _sectionCard(
          title: 'Data Usaha',
          children: [
            _textField(_companyName, 'Nama Badan Usaha', required: true),
            _textField(_businessType, 'Jenis Usaha', required: true),
            _textField(_nib, 'NIB (opsional)'),
            _textField(
              _companyAddress,
              'Alamat Usaha',
              maxLines: 2,
              required: true,
            ),
            _textField(_city, 'Kota', required: true),
            _textField(_province, 'Provinsi', required: true),
            _textField(
              _companyPhone,
              'Telepon Usaha',
              keyboardType: TextInputType.phone,
              required: true,
            ),
            _textField(
              _companyDescription,
              'Deskripsi Usaha (opsional)',
              maxLines: 3,
            ),
          ],
        ),
        _sectionCard(
          title: 'Data Venue',
          children: [
            _textField(_venueName, 'Nama Venue', required: true),
            _textField(_address, 'Alamat Venue', maxLines: 2, required: true),
            _textField(
              _contactPhone,
              'Nomor Kontak Venue',
              keyboardType: TextInputType.phone,
              required: true,
            ),
            _textField(
              _description,
              'Deskripsi Venue',
              maxLines: 3,
              required: true,
            ),
            const SizedBox(height: 8),
            const Text(
              'Cabang Olahraga',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _sportOptions.map((sport) {
                final selected = _sports.contains(sport);
                return FilterChip(
                  label: Text(sport),
                  selected: selected,
                  selectedColor: const Color(0xFFE6F5EA),
                  checkmarkColor: const Color(0xFF00A32A),
                  onSelected: (value) {
                    setState(() {
                      if (value) {
                        _sports.add(sport);
                      } else {
                        _sports.remove(sport);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            _dropdownField<String>(
              label: 'Status Kepemilikan',
              value: _ownershipType,
              items: const {'Milik Sendiri': 'Milik Sendiri', 'Sewa': 'Sewa'},
              onChanged: (value) => setState(() => _ownershipType = value!),
            ),
            _textField(_googleMapsUrl, 'Google Maps URL (opsional)'),
            _textField(_operatingHours, 'Jam Operasional', required: true),
            _textField(
              _latitude,
              'Latitude (opsional)',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
            ),
            _textField(
              _longitude,
              'Longitude (opsional)',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
            ),
            _textField(
              _facilities,
              'Fasilitas (pisahkan dengan koma)',
              maxLines: 2,
            ),
          ],
        ),
        _sectionCard(
          title: 'Dokumen Pendukung',
          children: [
            _documentTile('identity_document', required: true),
            if (_ownershipType == 'Sewa')
              _documentTile('lease_document', required: true)
            else
              _documentTile('ownership_document', required: true),
            if (_relationship == 'manager' || _relationship == 'representative')
              _documentTile('authorization_document', required: true),
            _documentTile('business_license'),
            _documentTile('venue_exterior_photo', required: true),
            _documentTile('venue_interior_photo', required: true),
          ],
        ),
        _sectionCard(
          title: 'Foto Fasilitas Lapangan',
          children: [
            if (_courtPhotos.isNotEmpty)
              SizedBox(
                height: 90,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _courtPhotos.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            File(_courtPhotos[index]),
                            width: 90,
                            height: 90,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stack) =>
                                const Icon(Icons.image_not_supported),
                          ),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _courtPhotos.removeAt(index)),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _addCourtPhotos,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text('Tambah Foto (${_courtPhotos.length}/8)'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        CheckboxListTile(
          value: _acceptedTerms,
          onChanged: (value) => setState(() => _acceptedTerms = value ?? false),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text(
            'Saya bertanggung jawab atas kebenaran data dan dokumen yang diajukan.',
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _isSubmitting ? null : _submit,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send),
            label: Text(_isSubmitting ? 'Mengirim...' : 'Kirim Pengajuan'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00A32A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _documentTile(String key, {bool required = false}) {
    final label = _documentLabels[key] ?? key;
    final picked = _documents[key];
    final exists = _hasDocument(label);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        exists || picked != null ? Icons.task_alt : Icons.upload_file_outlined,
        color: exists || picked != null ? const Color(0xFF00A32A) : Colors.grey,
      ),
      title: Text(label),
      subtitle: Text(
        picked != null
            ? _fileName(picked)
            : exists
            ? 'Sudah diunggah sebelumnya'
            : required
            ? 'Wajib diunggah (JPG/PNG)'
            : 'Opsional (JPG/PNG)',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (picked != null)
            IconButton(
              tooltip: 'Hapus',
              onPressed: () => setState(() => _documents.remove(key)),
              icon: const Icon(Icons.close, color: Colors.redAccent),
            ),
          IconButton(
            tooltip: 'Pilih file',
            onPressed: () => _chooseDocument(key),
            icon: const Icon(
              Icons.file_upload_outlined,
              color: Color(0xFF00A32A),
            ),
          ),
        ],
      ),
    );
  }

  String _fileName(String path) {
    final parts = path.split(RegExp(r'[\\/]'));
    return parts.isEmpty ? path : parts.last;
  }

  Widget _sectionCard({required String title, required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E2A2B),
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label, {
    bool required = false,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          alignLabelWithHint: maxLines > 1,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _dropdownField<T>({
    required String label,
    required T value,
    required Map<T, String> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<T>(
        initialValue: value,
        items: items.entries
            .map(
              (entry) => DropdownMenuItem<T>(
                value: entry.key,
                child: Text(entry.value),
              ),
            )
            .toList(),
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    final label = _statusLabel(status);
    final color = switch (status.toLowerCase()) {
      'approved' => const Color(0xFF00A32A),
      'rejected' => Colors.red,
      'revision' => Colors.orange,
      _ => Colors.blueGrey,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  String _statusLabel(String? status) {
    return switch (status?.toLowerCase()) {
      'pending' || 'menunggu' => 'Menunggu Verifikasi',
      'revision' || 'perlu revisi' => 'Perlu Revisi',
      'approved' => 'Disetujui',
      'rejected' => 'Ditolak',
      null || '' => '-',
      _ => status!,
    };
  }

  String _statusMessage(String status) {
    return switch (status.toLowerCase()) {
      'revision' || 'perlu revisi' =>
        'Pengajuan kamu perlu diperbaiki. Periksa catatan Superadmin di bawah.',
      'approved' =>
        'Selamat! Pengajuan venue kamu disetujui. Silakan masuk kembali untuk mengakses menu pengelola venue.',
      'rejected' =>
        'Pengajuan venue kamu ditolak. Kamu masih dapat mengajukan ulang melalui aplikasi.',
      _ =>
        'Pengajuan kamu sedang menunggu pemeriksaan Superadmin. Kamu akan menerima notifikasi saat status diperbarui.',
    };
  }
}
