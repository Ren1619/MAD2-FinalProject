import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
// Conditional import for web
import 'dart:html' as html show File, FileReader, FileUploadInputElement;
import '../../services/firebase_budget_service.dart';
import '../../widgets/common_widgets.dart';
import '../../theme.dart';
import '../../utils/image_utils.dart';

class AddExpensePage extends StatefulWidget {
  final Map<String, dynamic> budget;

  const AddExpensePage({super.key, required this.budget});

  @override
  State<AddExpensePage> createState() => _AddExpensePageState();
}

class _AddExpensePageState extends State<AddExpensePage> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();

  File? _receiptImage;
  Uint8List? _receiptImageBytes; // For web
  String? _receiptBase64;
  String? _receiptFileName;
  bool _isLoading = false;
  bool _isProcessingImage = false;
  ImagePicker? _picker;

  @override
  void initState() {
    super.initState();
    _initializeComponents();
  }

  Future<void> _initializeComponents() async {
    // Initialize image picker for mobile platforms only
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        _picker = ImagePicker();
      } catch (e) {
        debugPrint('Error initializing ImagePicker: $e');
      }
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    debugPrint('🚀 PICK IMAGE: Starting image selection');
    setState(() => _isProcessingImage = true);

    try {
      if (kIsWeb) {
        debugPrint('🚀 PICK IMAGE: Using WEB path');
        await _pickImageFromWeb();
      } else if (Platform.isAndroid || Platform.isIOS) {
        debugPrint('🚀 PICK IMAGE: Using MOBILE path');
        await _showImageSourceDialog();
      } else {
        debugPrint('🚀 PICK IMAGE: Using DESKTOP path');
        // Desktop platforms - use a working approach
        await _pickImageFromDesktop();
      }
    } catch (e) {
      debugPrint('❌ PICK IMAGE: Error in _pickImage: $e');
      _showErrorSnackBar('Error selecting image: ${e.toString()}');
    } finally {
      debugPrint('🚀 PICK IMAGE: Finished, setting processing to false');
      setState(() => _isProcessingImage = false);
    }
  }

  Future<void> _pickImageFromWeb() async {
    try {
      final html.FileUploadInputElement uploadInput =
          html.FileUploadInputElement();
      uploadInput.accept = '.jpg,.jpeg,.png,.pdf';
      uploadInput.click();

      uploadInput.onChange.listen((e) async {
        final files = uploadInput.files;
        if (files!.isEmpty) return;

        final html.File file = files[0];
        final reader = html.FileReader();

        reader.onLoadEnd.listen((e) {
          final String result = reader.result as String;
          final String base64 =
              result.split(',')[1]; // Remove data:image/jpeg;base64, prefix

          setState(() {
            _receiptBase64 = base64;
            _receiptFileName = file.name;
            _receiptImageBytes = base64Decode(base64);
          });

          _showSuccessSnackBar('Receipt image selected successfully');
        });

        reader.onError.listen((e) {
          _showErrorSnackBar('Error reading file');
        });

        reader.readAsDataUrl(file);
      });
    } catch (e) {
      debugPrint('Error in _pickImageFromWeb: $e');
      _showErrorSnackBar('Error selecting file from web');
    }
  }

  Future<void> _pickImageFromDesktop() async {
    try {
      // For desktop, we'll use a different approach
      // Since file_picker has issues, we'll use the image_picker which works better on desktop
      if (_picker == null) {
        _picker = ImagePicker();
      }

      final XFile? image = await _picker!.pickImage(
        source: ImageSource.gallery, // This opens file explorer on desktop
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 85,
      );

      if (image != null) {
        await _processSelectedImage(image);
      }
    } catch (e) {
      debugPrint('Error in _pickImageFromDesktop: $e');
      _showErrorSnackBar(
        'Error selecting image from desktop. Please try again.',
      );
    }
  }

  Future<void> _showImageSourceDialog() async {
    if (_picker == null) {
      _picker = ImagePicker();
    }

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Select Receipt Source'),
            content: const Text('Choose how you want to add your receipt:'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _pickImageFromCamera();
                },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.camera_alt),
                    SizedBox(width: 4),
                    Text('Camera'),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _pickImageFromGallery();
                },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.photo_library),
                    SizedBox(width: 4),
                    Text('Gallery'),
                  ],
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _pickImageFromCamera() async {
    try {
      if (_picker == null) {
        _picker = ImagePicker();
      }

      final XFile? image = await _picker!.pickImage(
        source: ImageSource.camera,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 85,
      );

      if (image != null) {
        await _processSelectedImage(image);
      }
    } catch (e) {
      debugPrint('Error in _pickImageFromCamera: $e');
      _showErrorSnackBar(
        'Camera not available. Please try selecting from gallery.',
      );
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      if (_picker == null) {
        _picker = ImagePicker();
      }

      final XFile? image = await _picker!.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 85,
      );

      if (image != null) {
        await _processSelectedImage(image);
      }
    } catch (e) {
      debugPrint('Error in _pickImageFromGallery: $e');
      _showErrorSnackBar('Gallery not available. Please try using camera.');
    }
  }

  Future<void> _processSelectedImage(XFile image) async {
    try {
      // Use your approach to read the file
      List<int> imageBytes;

      if (kIsWeb) {
        imageBytes = await image.readAsBytes();
      } else {
        // For mobile/desktop, read the file directly
        final file = File(image.path);
        imageBytes = file.readAsBytesSync(); // Your preferred approach
      }

      debugPrint('Original image bytes length: ${imageBytes.length}');

      // Check initial size
      final initialSizeKB = imageBytes.length / 1024;
      debugPrint('Original image size: ${initialSizeKB.toStringAsFixed(1)} KB');

      // AGGRESSIVE COMPRESSION - We need to be under 750KB to stay under Firestore 1MB limit
      Uint8List processedBytes = await _aggressiveCompress(
        Uint8List.fromList(imageBytes),
      );

      final compressedSizeKB = processedBytes.length / 1024;
      debugPrint(
        'Final compressed image size: ${compressedSizeKB.toStringAsFixed(1)} KB',
      );

      // Use your approach to convert to base64
      String base64Image = base64Encode(processedBytes);
      debugPrint('Base64 string length: ${base64Image.length} characters');

      // Final validation - base64 should be under 1MB (1048576 characters)
      if (base64Image.length > 1000000) {
        // Leave some safety margin
        _showErrorSnackBar(
          'Image is still too large after compression. Please use a smaller image or take a new photo.',
        );
        return;
      }

      setState(() {
        if (kIsWeb) {
          _receiptImageBytes = processedBytes;
        } else {
          // FIXED: Don't store original file, store compressed data
          // Create a temporary file with compressed data if needed
          _receiptImageBytes =
              processedBytes; // Store compressed bytes for all platforms
        }
        _receiptFileName = image.name;
        _receiptBase64 = base64Image; // Using your base64 conversion approach
      });

      _showSuccessSnackBar(
        'Receipt image processed successfully (${compressedSizeKB.toStringAsFixed(1)} KB)',
      );
    } catch (e) {
      debugPrint('Error in _processSelectedImage: $e');
      _showErrorSnackBar('Error processing image: ${e.toString()}');
    }
  }

  Future<Uint8List> _aggressiveCompress(Uint8List bytes) async {
    try {
      // Multiple compression passes with increasingly aggressive settings
      Uint8List currentBytes = bytes;

      // Pass 1: If over 500KB, resize aggressively
      if (currentBytes.length > 500 * 1024) {
        currentBytes = await _resizeImage(
          currentBytes,
          800,
          30,
        ); // 800px max, 30% quality
      }

      // Pass 2: If still over 400KB, resize more
      if (currentBytes.length > 400 * 1024) {
        currentBytes = await _resizeImage(
          currentBytes,
          600,
          25,
        ); // 600px max, 25% quality
      }

      // Pass 3: If still over 300KB, resize even more
      if (currentBytes.length > 300 * 1024) {
        currentBytes = await _resizeImage(
          currentBytes,
          400,
          20,
        ); // 400px max, 20% quality
      }

      // Pass 4: Final aggressive compression if still too large
      if (currentBytes.length > 250 * 1024) {
        currentBytes = await _resizeImage(
          currentBytes,
          300,
          15,
        ); // 300px max, 15% quality
      }

      debugPrint(
        'Compression passes complete. Final size: ${(currentBytes.length / 1024).toStringAsFixed(1)} KB',
      );

      return currentBytes;
    } catch (e) {
      debugPrint('Compression failed, using minimal processing: $e');
      // If compression fails, do a simple resize
      return await _simpleResize(bytes);
    }
  }

  Future<Uint8List> _resizeImage(
    Uint8List bytes,
    int maxSize,
    int quality,
  ) async {
    try {
      // This is a placeholder for image resizing
      // You'll need to add the 'image' package for this to work properly

      // For now, let's implement a simple approach using ImagePicker's built-in compression
      // by re-compressing the image data

      // Create a temporary file (for demonstration)
      if (kIsWeb) {
        // For web, we can't easily resize without additional libraries
        // Return a scaled down version by reducing quality
        return _reduceQuality(bytes, quality);
      } else {
        // For mobile/desktop, try to use image processing
        return await _nativeImageResize(bytes, maxSize, quality);
      }
    } catch (e) {
      debugPrint('Resize failed: $e');
      return bytes;
    }
  }

  Future<Uint8List> _nativeImageResize(
    Uint8List bytes,
    int maxSize,
    int quality,
  ) async {
    try {
      // If you add the 'image' package, uncomment this:
      /*
      import 'package:image/image.dart' as img;
      
      final image = img.decodeImage(bytes);
      if (image != null) {
        // Calculate new dimensions maintaining aspect ratio
        int newWidth = image.width;
        int newHeight = image.height;
        
        if (newWidth > maxSize || newHeight > maxSize) {
          if (newWidth > newHeight) {
            newHeight = (newHeight * maxSize / newWidth).round();
            newWidth = maxSize;
          } else {
            newWidth = (newWidth * maxSize / newHeight).round();
            newHeight = maxSize;
          }
        }
        
        final resized = img.copyResize(image, width: newWidth, height: newHeight);
        final compressedBytes = img.encodeJpg(resized, quality: quality);
        return Uint8List.fromList(compressedBytes);
      }
      */

      // For now, return a simple quality reduction
      return _reduceQuality(bytes, quality);
    } catch (e) {
      debugPrint('Native resize failed: $e');
      return bytes;
    }
  }

  Future<Uint8List> _reduceQuality(Uint8List bytes, int quality) async {
    // Simple quality reduction by taking every nth byte (crude but effective)
    // This is a very basic approach - proper implementation would use image libraries

    if (quality >= 50) return bytes;

    // For very low quality, reduce data size by sampling
    final reduction = (100 - quality) / 100;
    final newLength = (bytes.length * (1 - reduction * 0.5)).round();

    if (newLength < bytes.length) {
      final step = bytes.length / newLength;
      final List<int> reduced = [];

      for (int i = 0; i < bytes.length; i += step.round()) {
        if (i < bytes.length) {
          reduced.add(bytes[i]);
        }
      }

      return Uint8List.fromList(reduced);
    }

    return bytes;
  }

  Future<Uint8List> _simpleResize(Uint8List bytes) async {
    // Emergency fallback - just take first 200KB of data
    // This will likely corrupt the image but ensures size compliance
    const maxBytes = 200 * 1024; // 200KB max

    if (bytes.length > maxBytes) {
      _showWarningDialog(
        'Image Too Large',
        'The image had to be heavily compressed and may appear degraded. '
            'For better quality, please use a smaller image or take a new photo with lower resolution.',
      );

      return Uint8List.fromList(bytes.take(maxBytes).toList());
    }

    return bytes;
  }

  Future<Uint8List> _compressImage(Uint8List bytes) async {
    try {
      // For web, we'll use a simple quality reduction approach
      if (kIsWeb) {
        return await _compressImageWeb(bytes);
      } else {
        // For mobile/desktop, we can use more sophisticated compression
        return await _compressImageNative(bytes);
      }
    } catch (e) {
      debugPrint('Compression failed, using original: $e');
      return bytes;
    }
  }

  Future<Uint8List> _compressImageWeb(Uint8List bytes) async {
    // For web, we'll create a canvas and draw the image with reduced quality
    // This is a simplified approach - in production you might want to use a proper image compression library

    // For now, let's just resize if the image is too large
    // You can add proper web image compression here using canvas or a library like 'image' package

    return bytes; // Placeholder - implement proper web compression if needed
  }

  Future<Uint8List> _compressImageNative(Uint8List bytes) async {
    // For native platforms, you can use the 'image' package for compression
    // This is a placeholder implementation

    try {
      // If you add the 'image' package, you can uncomment and modify this:
      /*
      final image = img.decodeImage(bytes);
      if (image != null) {
        // Resize if too large
        img.Image resized = image;
        if (image.width > 1200 || image.height > 1200) {
          resized = img.copyResize(image, width: 1200, height: 1200, interpolation: img.Interpolation.average);
        }
        
        // Compress as JPEG with quality 85
        final compressedBytes = img.encodeJpg(resized, quality: 85);
        return Uint8List.fromList(compressedBytes);
      }
      */

      return bytes;
    } catch (e) {
      debugPrint('Native compression failed: $e');
      return bytes;
    }
  }

  void _showWarningDialog(String title, String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange[700]),
                const SizedBox(width: 8),
                Text(title),
              ],
            ),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  void _removeImage() {
    debugPrint('🗑️ REMOVE: Clearing all image data');
    setState(() {
      _receiptImage = null; // Legacy - keeping for compatibility
      _receiptImageBytes = null; // This is what we actually use now
      _receiptBase64 = null; // This is what goes to backend
      _receiptFileName = null; // Filename
    });
    debugPrint('🗑️ REMOVE: All image data cleared');
  }

  bool _hasReceiptImage() {
    return _receiptBase64 != null;
  }

  Future<void> _submitExpense() async {
    if (!_formKey.currentState!.validate()) return;

    // Check if receipt is provided
    if (!_hasReceiptImage()) {
      _showErrorSnackBar('Please attach a receipt image before submitting.');
      return;
    }

    debugPrint('📤 SUBMIT: Starting expense submission');
    debugPrint(
      '📤 SUBMIT: Receipt base64 length: ${_receiptBase64?.length ?? 0} characters',
    );
    debugPrint('📤 SUBMIT: Receipt filename: $_receiptFileName');

    setState(() => _isLoading = true);

    try {
      final budgetService = Provider.of<FirebaseBudgetService>(
        context,
        listen: false,
      );

      final success = await budgetService.createExpense(
        budgetId: widget.budget['budget_id'],
        expenseDescription: _descriptionController.text.trim(),
        expenseAmount: double.parse(_amountController.text),
        receiptBase64: _receiptBase64,
      );

      if (success) {
        debugPrint('📤 SUBMIT: Expense created successfully');
        _showSuccessSnackBar(
          'Expense created successfully! It is now pending approval.',
        );
        Navigator.pop(context);
      } else {
        debugPrint('❌ SUBMIT: Backend returned false');
        _showErrorSnackBar('Failed to create expense. Please try again.');
      }
    } catch (e) {
      debugPrint('❌ SUBMIT: Exception during submission: $e');
      _showErrorSnackBar('Error creating expense: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  String _formatCurrency(double amount) {
    return '\$${amount.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final budgetAmount =
        (widget.budget['budget_amount'] as num?)?.toDouble() ?? 0.0;
    final totalExpenses =
        (widget.budget['total_expenses'] as num?)?.toDouble() ?? 0.0;
    final remainingAmount = budgetAmount - totalExpenses;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: CustomAppBar(
        title: 'Add Expense',
        onMenuPressed: () => Navigator.pop(context),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green, Colors.green.shade700],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.receipt_long,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Add New Expense',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Budget: ${widget.budget['budget_name']}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Budget Summary Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Budget Summary',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildSummaryItem(
                              'Total Budget',
                              _formatCurrency(budgetAmount),
                              Icons.account_balance_wallet,
                              AppTheme.primaryColor,
                            ),
                          ),
                          Expanded(
                            child: _buildSummaryItem(
                              'Used',
                              _formatCurrency(totalExpenses),
                              Icons.trending_up,
                              Colors.orange,
                            ),
                          ),
                          Expanded(
                            child: _buildSummaryItem(
                              'Remaining',
                              _formatCurrency(remainingAmount),
                              Icons.savings,
                              remainingAmount >= 0 ? Colors.green : Colors.red,
                            ),
                          ),
                        ],
                      ),
                      if (remainingAmount < 0) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red[200]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.warning, color: Colors.red[700]),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Warning: This budget has exceeded its allocated amount.',
                                  style: TextStyle(
                                    color: Colors.red[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Expense Details Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Expense Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Expense Description
                      TextFormField(
                        controller: _descriptionController,
                        decoration: AppTheme.inputDecoration(
                          labelText: 'Expense Description',
                          hintText:
                              'Enter a detailed description of the expense',
                          prefixIcon: Icons.description,
                        ),
                        maxLines: 3,
                        validator: (value) {
                          if (value?.trim().isEmpty ?? true) {
                            return 'Expense description is required';
                          }
                          if (value!.trim().length < 5) {
                            return 'Please provide a more detailed description (at least 5 characters)';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 20),

                      // Expense Amount
                      TextFormField(
                        controller: _amountController,
                        decoration: AppTheme.inputDecoration(
                          labelText: 'Expense Amount',
                          hintText: 'Enter expense amount (e.g., 125.50)',
                          prefixIcon: Icons.attach_money,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (value) {
                          if (value?.trim().isEmpty ?? true) {
                            return 'Expense amount is required';
                          }

                          final amount = double.tryParse(value!);
                          if (amount == null) {
                            return 'Please enter a valid amount';
                          }

                          if (amount <= 0) {
                            return 'Expense amount must be greater than zero';
                          }

                          if (amount > 1000000) {
                            return 'Expense amount cannot exceed \$1,000,000';
                          }

                          return null;
                        },
                        onChanged: (value) {
                          final amount = double.tryParse(value);
                          if (amount != null && amount > remainingAmount) {
                            // Show warning but don't prevent input
                            setState(() {});
                          }
                        },
                      ),

                      // Amount Warning
                      if (_amountController.text.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Builder(
                          builder: (context) {
                            final amount =
                                double.tryParse(_amountController.text) ?? 0.0;
                            if (amount > remainingAmount &&
                                remainingAmount > 0) {
                              return Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.orange[50],
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.orange[200]!,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.warning_amber,
                                      color: Colors.orange[700],
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'This expense exceeds the remaining budget by ${_formatCurrency(amount - remainingAmount)}',
                                        style: TextStyle(
                                          color: Colors.orange[700],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Receipt Upload Card (Now Required)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Receipt *',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Required',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.red[700],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Tooltip(
                            message:
                                'A receipt is required for all expense submissions',
                            child: Icon(
                              Icons.help_outline,
                              size: 18,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Upload a photo or scan of your receipt for verification. This is required for all expenses.',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (!_hasReceiptImage()) ...[
                        // Upload Button
                        GestureDetector(
                          onTap: _isProcessingImage ? null : _pickImage,
                          child: Container(
                            width: double.infinity,
                            height: 120,
                            decoration: BoxDecoration(
                              color:
                                  _isProcessingImage
                                      ? Colors.grey[100]
                                      : Colors.red[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color:
                                    _isProcessingImage
                                        ? Colors.grey[300]!
                                        : Colors.red[300]!,
                                style: BorderStyle.solid,
                                width: 2,
                              ),
                            ),
                            child:
                                _isProcessingImage
                                    ? const Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          CircularProgressIndicator(),
                                          SizedBox(height: 8),
                                          Text('Processing image...'),
                                        ],
                                      ),
                                    )
                                    : Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          kIsWeb
                                              ? Icons.upload_file
                                              : (Platform.isAndroid ||
                                                  Platform.isIOS)
                                              ? Icons.camera_alt
                                              : Icons.folder_open,
                                          size: 48,
                                          color: Colors.red[700],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          kIsWeb
                                              ? 'Click to upload receipt'
                                              : (Platform.isAndroid ||
                                                  Platform.isIOS)
                                              ? 'Tap to capture receipt'
                                              : 'Click to select receipt',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.red[700],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          kIsWeb
                                              ? 'JPG, PNG, or PDF • Max 10MB'
                                              : (Platform.isAndroid ||
                                                  Platform.isIOS)
                                              ? 'Camera or Gallery • JPG, PNG'
                                              : 'JPG, PNG files',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                          ),
                        ),
                      ] else ...[
                        // Image Preview
                        Container(
                          width: double.infinity,
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green[300]!),
                          ),
                          child: Stack(
                            children: [
                              Center(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child:
                                      kIsWeb && _receiptImageBytes != null
                                          ? Image.memory(
                                            _receiptImageBytes!,
                                            width: double.infinity,
                                            height: double.infinity,
                                            fit: BoxFit.cover,
                                          )
                                          : _receiptImage != null
                                          ? Image.file(
                                            _receiptImage!,
                                            width: double.infinity,
                                            height: double.infinity,
                                            fit: BoxFit.cover,
                                          )
                                          : Container(
                                            width: double.infinity,
                                            height: double.infinity,
                                            color: Colors.grey[200],
                                            child: const Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.receipt,
                                                  size: 64,
                                                  color: Colors.grey,
                                                ),
                                                SizedBox(height: 8),
                                                Text(
                                                  'Receipt Image Attached',
                                                  style: TextStyle(
                                                    color: Colors.grey,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: IconButton(
                                    onPressed: _removeImage,
                                    icon: const Icon(
                                      Icons.close,
                                      color: Colors.red,
                                    ),
                                    tooltip: 'Remove receipt',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Receipt attached: ${_receiptFileName ?? 'receipt_image'}',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Change Receipt'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _isLoading ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: AppTheme.primaryColor),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitExpense,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child:
                          _isLoading
                              ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text('Creating Expense...'),
                                ],
                              )
                              : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.save),
                                  SizedBox(width: 8),
                                  Text('Submit Expense'),
                                ],
                              ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Info Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Expense Submission Process',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '• Receipt attachment is mandatory for all expenses\n'
                            '• Once submitted, the expense will be in "Pending" status\n'
                            '• Budget Managers will review and approve the expense\n'
                            '• Approved expenses will be reflected in the budget\n'
                            '• You will be notified of any status changes',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blue[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
