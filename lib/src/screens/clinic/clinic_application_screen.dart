import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/clinic.dart';
import '../../models/user.dart' as models;
import '../../services/database_service.dart';
import 'clinic_location_picker_screen.dart';

class ClinicApplicationScreen extends StatefulWidget {
  const ClinicApplicationScreen({super.key});

  @override
  State<ClinicApplicationScreen> createState() => _ClinicApplicationScreenState();
}

class _ClinicApplicationScreenState extends State<ClinicApplicationScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _appealController = TextEditingController();

  models.User? _user;
  Clinic? _clinic;
  bool _loading = true;
  bool _saving = false;
  bool _uploadingImages = false;
  List<String> _establishmentImages = [];
  final List<_PendingImage> _pendingImages = [];
  final ImagePicker _imagePicker = ImagePicker();

  static const int _maxClinicImages = 5;

  int get _imageCount => _establishmentImages.length + _pendingImages.length;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    _user = await DatabaseService.instance.getCurrentUser();
    if (_user?.id != null) {
      _clinic = await DatabaseService.instance.fetchClinicByOwner(_user!.id!);
      if (_clinic != null) {
        _nameController.text = _clinic!.name;
        _descriptionController.text = _clinic!.description;
        _addressController.text = _clinic!.address;
        _phoneController.text = _clinic!.phone;
        _appealController.text = _clinic!.appealMessage;
        _establishmentImages = List<String>.from(_clinic!.establishmentImages);
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _submit() async {
    if (_user?.id == null) return;
    if (_nameController.text.trim().isEmpty) {
      _showMessage('Clinic name is required.');
      return;
    }

    setState(() => _saving = true);
    try {
      _clinic = await DatabaseService.instance.submitClinicApplication(
        ownerId: _user!.id!,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        address: _addressController.text.trim(),
        phone: _phoneController.text.trim(),
        existingClinicId: _clinic?.id,
      );
      await _flushPendingImages();
      if (!mounted) return;
      _showMessage('Application submitted. Waiting for admin approval.');
      setState(() {});
    } catch (e) {
      _showMessage(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveDetails() async {
    if (_clinic?.id == null || !_clinic!.isApproved || !_clinic!.isActiveListing) return;
    if (_nameController.text.trim().isEmpty) {
      _showMessage('Clinic name is required.');
      return;
    }

    setState(() => _saving = true);
    try {
      _clinic = await DatabaseService.instance.updateClinicDetails(
        clinicId: _clinic!.id!,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        address: _addressController.text.trim(),
        phone: _phoneController.text.trim(),
      );
      await _flushPendingImages();
      _showMessage('Clinic details updated.');
    } catch (e) {
      _showMessage(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _submitAppeal() async {
    if (_clinic?.id == null) return;
    if (_appealController.text.trim().isEmpty) {
      _showMessage('Please explain why your clinic should be restored.');
      return;
    }

    setState(() => _saving = true);
    try {
      _clinic = await DatabaseService.instance.submitClinicAppeal(
        clinicId: _clinic!.id!,
        message: _appealController.text.trim(),
      );
      _showMessage('Appeal submitted. An admin will review it.');
      setState(() {});
    } catch (e) {
      _showMessage(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openLocationPicker() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ClinicLocationPickerScreen(clinic: _clinic),
      ),
    );
    if (result == true && mounted) {
      _loadData();
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _statusBanner() {
    if (_clinic == null) {
      return const Card(
        color: Color(0xFFE3F2FD),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Text('Submit your clinic details to apply for listing on the patient directory.'),
        ),
      );
    }

    Color color;
    String message;

    if (_clinic!.isHiddenFromPatients) {
      color = Colors.red.shade100;
      final action = _clinic!.isTerminated ? 'terminated' : 'disabled';
      message =
          'Your clinic has been $action and is hidden from patients.${_clinic!.statusReason.isNotEmpty ? '\nReason: ${_clinic!.statusReason}' : ''}';
    } else if (_clinic!.isApproved && _clinic!.isActiveListing) {
      color = Colors.green.shade100;
      message = 'Approved — your clinic is visible to patients.';
    } else if (_clinic!.isRejected) {
      color = Colors.red.shade100;
      message =
          'Rejected — update your details and resubmit.${_clinic!.adminNotes.isNotEmpty ? '\nAdmin note: ${_clinic!.adminNotes}' : ''}';
    } else {
      color = Colors.orange.shade100;
      message = 'Pending — an admin is reviewing your application.';
    }

    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(message),
      ),
    );
  }

  Widget _appealSection() {
    if (_clinic == null || !_clinic!.isHiddenFromPatients) return const SizedBox.shrink();

    if (_clinic!.hasPendingAppeal) {
      return Card(
        color: Colors.orange.shade50,
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: Text('Your appeal is pending admin review.'),
        ),
      );
    }

    if (_clinic!.appealStatus == 'rejected') {
      return Card(
        color: Colors.red.shade50,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            'Your last appeal was rejected.${_clinic!.adminNotes.isNotEmpty ? '\nAdmin note: ${_clinic!.adminNotes}' : ''}\nYou may submit a new appeal below.',
          ),
        ),
      );
    }

    if (!_clinic!.canSubmitAppeal) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Submit an appeal', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: _appealController,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: 'Why should your clinic be restored?',
            hintText: 'Explain corrective actions or context for the admin.',
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _saving ? null : _submitAppeal,
          child: _saving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Submit Appeal'),
        ),
      ],
    );
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 80,
      );

      if (images.isEmpty) return;

      final remaining = _maxClinicImages - _imageCount;
      if (images.length > remaining) {
        _showMessage(
          'Maximum $_maxClinicImages images allowed. You can add $remaining more.',
        );
        return;
      }

      setState(() => _uploadingImages = true);

      final db = DatabaseService.instance;
      final clinicId = _clinic?.id;

      for (final image in images) {
        try {
          final bytes = await image.readAsBytes();

          if (clinicId == null) {
            // No clinic record yet — keep locally and upload after submission.
            setState(() => _pendingImages.add(_PendingImage(bytes, image.name)));
            continue;
          }

          final publicUrl = await db.uploadClinicImage(
            clinicId: clinicId,
            fileBytes: bytes,
            fileName: image.name,
          );
          setState(() => _establishmentImages.add(publicUrl));
        } catch (e) {
          _showMessage('Failed to add ${image.name}: $e');
        }
      }

      if (clinicId != null) {
        await db.updateClinicImages(
          clinicId: clinicId,
          imageUrls: List<String>.from(_establishmentImages),
        );
      }
    } catch (e) {
      _showMessage('Failed to pick images: $e');
    } finally {
      if (mounted) setState(() => _uploadingImages = false);
    }
  }

  /// Uploads locally staged images once a clinic record exists.
  Future<void> _flushPendingImages() async {
    final clinicId = _clinic?.id;
    if (clinicId == null || _pendingImages.isEmpty) return;

    final db = DatabaseService.instance;
    final pending = List<_PendingImage>.from(_pendingImages);

    for (final pendingImage in pending) {
      try {
        final publicUrl = await db.uploadClinicImage(
          clinicId: clinicId,
          fileBytes: pendingImage.bytes,
          fileName: pendingImage.name,
        );
        if (!mounted) return;
        setState(() {
          _pendingImages.remove(pendingImage);
          _establishmentImages.add(publicUrl);
        });
      } catch (e) {
        _showMessage('Failed to upload ${pendingImage.name}: $e');
      }
    }

    if (_establishmentImages.isNotEmpty) {
      await db.updateClinicImages(
        clinicId: clinicId,
        imageUrls: List<String>.from(_establishmentImages),
      );
    }
  }

  void _removeImage(int index) {
    setState(() {
      if (index < _establishmentImages.length) {
        _establishmentImages.removeAt(index);
      } else {
        _pendingImages.removeAt(index - _establishmentImages.length);
      }
    });

    final clinicId = _clinic?.id;
    if (clinicId != null) {
      DatabaseService.instance.updateClinicImages(
        clinicId: clinicId,
        imageUrls: List<String>.from(_establishmentImages),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final canEditApproved = _clinic?.isApproved == true && _clinic!.isActiveListing;
    final fieldsEnabled = _clinic == null || !_clinic!.isHiddenFromPatients;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _statusBanner(),
          const SizedBox(height: 16),
          _appealSection(),
          if (_clinic?.isHiddenFromPatients == true) const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            enabled: fieldsEnabled,
            decoration: const InputDecoration(labelText: 'Clinic Name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            enabled: fieldsEnabled,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Description'),
          ),
          const SizedBox(height: 12),
          // Establishment images section
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Establishment Images', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Text(
                    '($_imageCount/$_maxClinicImages)',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Upload up to 5 images of your clinic for verification.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              if (_imageCount > 0)
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _imageCount,
                    itemBuilder: (context, index) {
                      final isUploaded = index < _establishmentImages.length;
                      final Widget image = isUploaded
                          ? Image.network(
                              _establishmentImages[index],
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                width: 100,
                                color: Colors.grey.shade200,
                                child: const Icon(Icons.broken_image),
                              ),
                            )
                          : Image.memory(
                              _pendingImages[index - _establishmentImages.length].bytes,
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                            );

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: image,
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => _removeImage(index),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close, size: 16, color: Colors.white),
                                ),
                              ),
                            ),
                            if (!isUploaded)
                              Positioned(
                                bottom: 4,
                                left: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Pending',
                                    style: TextStyle(fontSize: 10, color: Colors.white),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed:
                    (_uploadingImages || _imageCount >= _maxClinicImages) ? null : _pickImages,
                icon: _uploadingImages
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_a_photo),
                label: Text(
                  _imageCount >= _maxClinicImages
                      ? 'Maximum images reached'
                      : (_uploadingImages ? 'Adding...' : 'Add Images'),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _addressController,
            enabled: fieldsEnabled,
            decoration: const InputDecoration(labelText: 'Address'),
          ),
          const SizedBox(height: 12),
          if (_clinic?.isApproved == true && _clinic!.isActiveListing)
            ElevatedButton.icon(
              onPressed: _saving ? null : _openLocationPicker,
              icon: const Icon(Icons.location_on),
              label: Text(_clinic!.hasValidLocation
                  ? 'Update Location on Map'
                  : 'Set Location on Map'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
            ),
          if (_clinic?.isApproved == true && _clinic!.isActiveListing)
            const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            enabled: fieldsEnabled,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone'),
          ),
          const SizedBox(height: 20),
          if (canEditApproved)
            ElevatedButton(
              onPressed: _saving ? null : _saveDetails,
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save Clinic Details'),
            )
          else if (fieldsEnabled)
            ElevatedButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_clinic == null ? 'Submit Application' : 'Resubmit Application'),
            ),
        ],
      ),
    );
  }
}

/// A clinic image picked locally and not yet uploaded to storage.
/// Used for applications that are submitted before a clinic record exists.
class _PendingImage {
  const _PendingImage(this.bytes, this.name);

  final Uint8List bytes;
  final String name;
}
