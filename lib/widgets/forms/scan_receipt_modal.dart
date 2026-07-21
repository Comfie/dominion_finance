import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../providers/expenses_provider.dart';
import '../../repositories/ai_repository.dart';
import '../../repositories/repository_providers.dart';

/// Modal for scanning receipts using camera or gallery
/// Follows SKILL.md guidelines for proper state management and error handling
class ScanReceiptModal extends ConsumerStatefulWidget {
  const ScanReceiptModal({super.key});

  @override
  ConsumerState<ScanReceiptModal> createState() => _ScanReceiptModalState();
}

class _ScanReceiptModalState extends ConsumerState<ScanReceiptModal> {
  final ImagePicker _picker = ImagePicker();
  XFile? _imageFile;
  bool _isScanning = false;
  ScannedReceipt? _scannedData;
  String? _error;

  // Form controllers for editing scanned data
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  ExpenseCategory? _selectedCategory;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  /// Pick image from camera
  Future<void> _pickFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null && mounted) {
        setState(() {
          _imageFile = image;
          _error = null;
        });
        await _scanReceipt();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to capture image: $e';
        });
      }
    }
  }

  /// Pick image from gallery
  Future<void> _pickFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null && mounted) {
        setState(() {
          _imageFile = image;
          _error = null;
        });
        await _scanReceipt();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to select image: $e';
        });
      }
    }
  }

  /// Scan receipt using AI
  Future<void> _scanReceipt() async {
    if (_imageFile == null) return;

    setState(() {
      _isScanning = true;
      _error = null;
    });

    try {
      // Read image as bytes and convert to base64
      final bytes = await File(_imageFile!.path).readAsBytes();
      final base64Image = base64Encode(bytes);

      // Determine MIME type
      final mimeType = _imageFile!.path.toLowerCase().endsWith('.png')
          ? 'image/png'
          : 'image/jpeg';

      // Call API to scan receipt
      final aiRepository = ref.read(aiRepositoryProvider);
      final scanned = await aiRepository.scanReceipt(base64Image, mimeType);

      if (mounted) {
        setState(() {
          _scannedData = scanned;
          _nameController.text = scanned.name ?? '';
          _amountController.text = scanned.amount?.toString() ?? '';

          // Try to match category from scanned data
          final categoryStr = scanned.category;
          if (categoryStr != null) {
            try {
              _selectedCategory = ExpenseCategory.values.firstWhere(
                (c) => c.name.toUpperCase() == categoryStr.toUpperCase(),
              );
            } catch (e) {
              _selectedCategory = null;
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to scan receipt: ${e.toString()}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  /// Create expense from scanned data
  Future<void> _createExpense() async {
    if (_nameController.text.isEmpty || _amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in name and amount'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    final data = {
      'name': _nameController.text,
      'amount': amount,
      'category': _selectedCategory?.name ?? ExpenseCategory.OTHER.name,
      'date': DateTime.now().toIso8601String(),
    };

    final success = await ref.read(expensesProvider.notifier).createExpense(data);

    if (mounted) {
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Expense created from receipt'),
            backgroundColor: AppTheme.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to create expense'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Scan Receipt',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Image picker buttons
              if (_imageFile == null) ...[
                Text(
                  'Choose a method to capture receipt',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickFromCamera,
                        icon: const Icon(Icons.camera_alt_rounded),
                        label: const Text('Camera'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickFromGallery,
                        icon: const Icon(Icons.photo_library_rounded),
                        label: const Text('Gallery'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              // Image preview
              if (_imageFile != null) ...[
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.textMuted.withOpacity(0.3)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(_imageFile!.path),
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (!_isScanning && _scannedData == null)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _pickFromGallery,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Choose Different Image'),
                    ),
                  ),
              ],

              // Loading indicator
              if (_isScanning) ...[
                const SizedBox(height: 16),
                const Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('Scanning receipt...'),
                    ],
                  ),
                ),
              ],

              // Error message
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: AppTheme.error),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(color: AppTheme.error),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _scanReceipt,
                    child: const Text('Retry Scan'),
                  ),
                ),
              ],

              // Scanned data form
              if (_scannedData != null && !_isScanning) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: AppTheme.success),
                      const SizedBox(width: 12),
                      const Text('Receipt scanned successfully!'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Review and Edit',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    border: OutlineInputBorder(),
                    prefixText: 'R ',
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<ExpenseCategory>(
                  value: _selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: ExpenseCategory.values.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category.displayName),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value;
                    });
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _createExpense,
                    child: const Text('Create Expense'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
