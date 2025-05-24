import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:html' as html show File, FileReader, FileUploadInputElement;
import 'package:image/image.dart' as img;
import '../../services/firebase_budget_service.dart';
import '../../widgets/common_widgets.dart';
import '../../theme.dart';
import '../../utils/image_utils.dart';
import 'dart:async';

class AddExpensePage extends StatefulWidget {
  final Map<String, dynamic> budget;

  const AddExpensePage({super.key, required this.budget});

  @override
  State<AddExpensePage> createState() => _AddExpensePageState();
}

class _AddExpensePageState extends State<AddExpensePage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionFocus = FocusNode();
  final _amountFocus = FocusNode();

  Uint8List? _receiptImageBytes;
  String? _receiptBase64;
  String? _receiptFileName;
  bool _isLoading = false;
  bool _isProcessingImage = false;
  ImagePicker? _picker;

  // Amount validation
  double? _currentAmount;
  Timer? _amountDebouncer;

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _receiptAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _receiptScaleAnimation;

  // Target size constants
  static const int _maxFileSizeBytes = 900 * 1024; // 900KB to stay under 1MB
  static const int _maxImageDimension = 1200; // Max width or height
  static const int _compressionQuality = 85; // JPEG quality

  @override
  void initState() {
    super.initState();
    _initializeComponents();
    _initializeAnimations();
    _setupTextFieldListeners();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _receiptAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );

    _receiptScaleAnimation = CurvedAnimation(
      parent: _receiptAnimationController,
      curve: Curves.elasticOut,
    );

    _fadeController.forward();
    _slideController.forward();
  }

  void _setupTextFieldListeners() {
    _amountController.addListener(() {
      _amountDebouncer?.cancel();
      _amountDebouncer = Timer(const Duration(milliseconds: 500), () {
        if (mounted) {
          final text = _amountController.text.replaceAll(RegExp(r'[^\d.]'), '');
          setState(() {
            _currentAmount = double.tryParse(text);
          });
        }
      });
    });
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
    _amountDebouncer?.cancel();
    _descriptionController.dispose();
    _amountController.dispose();
    _descriptionFocus.dispose();
    _amountFocus.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _receiptAnimationController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    debugPrint('🚀 PICK IMAGE: Starting image selection');
    setState(() => _isProcessingImage = true);

    // Haptic feedback
    HapticFeedback.selectionClick();

    try {
      if (kIsWeb) {
        debugPrint('🚀 PICK IMAGE: Using WEB path');
        await _pickImageFromWeb();
      } else if (Platform.isAndroid || Platform.isIOS) {
        debugPrint('🚀 PICK IMAGE: Using MOBILE path');
        await _showImageSourceDialog();
      } else {
        debugPrint('🚀 PICK IMAGE: Using DESKTOP path');
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
      uploadInput.accept = '.jpg,.jpeg,.png';
      uploadInput.click();

      uploadInput.onChange.listen((e) async {
        final files = uploadInput.files;
        if (files!.isEmpty) return;

        final html.File file = files[0];

        // Check file size before processing
        if (file.size > 10 * 1024 * 1024) {
          // 10MB limit
          _showErrorSnackBar(
            'File is too large. Please select an image smaller than 10MB.',
          );
          return;
        }

        final reader = html.FileReader();

        reader.onLoadEnd.listen((e) async {
          try {
            final String result = reader.result as String;
            final String base64 = result.split(',')[1];
            final Uint8List bytes = base64Decode(base64);

            debugPrint(
              'Original file size: ${bytes.length} bytes (${(bytes.length / 1024).toStringAsFixed(1)} KB)',
            );

            // Compress the image
            final compressedBytes = await _compressImageBytes(bytes);
            final compressedBase64 = base64Encode(compressedBytes);

            setState(() {
              _receiptImageBytes = compressedBytes;
              _receiptBase64 = compressedBase64;
              _receiptFileName = file.name;
            });

            // Animate receipt appearance
            _receiptAnimationController.forward();

            _showSuccessSnackBar(
              'Receipt image processed successfully (${(compressedBytes.length / 1024).toStringAsFixed(1)} KB)',
            );
          } catch (e) {
            debugPrint('Error processing web image: $e');
            _showErrorSnackBar('Error processing image: ${e.toString()}');
          }
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
      if (_picker == null) {
        _picker = ImagePicker();
      }

      final XFile? image = await _picker!.pickImage(
        source: ImageSource.gallery,
        maxWidth: _maxImageDimension.toDouble(),
        maxHeight: _maxImageDimension.toDouble(),
        imageQuality: _compressionQuality,
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('Select Receipt Source'),
            content: const Text('Choose how you want to add your receipt:'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _pickImageFromCamera();
                },
                icon: const Icon(Icons.camera_alt),
                label: const Text('Camera'),
              ),
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _pickImageFromGallery();
                },
                icon: const Icon(Icons.photo_library),
                label: const Text('Gallery'),
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
        maxWidth: _maxImageDimension.toDouble(),
        maxHeight: _maxImageDimension.toDouble(),
        imageQuality: _compressionQuality,
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
        maxWidth: _maxImageDimension.toDouble(),
        maxHeight: _maxImageDimension.toDouble(),
        imageQuality: _compressionQuality,
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
      debugPrint('Processing selected image: ${image.name}');

      // Read image bytes
      final Uint8List imageBytes = await image.readAsBytes();
      debugPrint(
        'Original image size: ${imageBytes.length} bytes (${(imageBytes.length / 1024).toStringAsFixed(1)} KB)',
      );

      // Compress the image
      final compressedBytes = await _compressImageBytes(imageBytes);

      // Convert to base64
      final base64String = base64Encode(compressedBytes);

      // Validate final size
      if (base64String.length > 1048576) {
        // 1MB in base64 characters
        throw 'Image is still too large after compression. Please use a smaller image.';
      }

      setState(() {
        _receiptImageBytes = compressedBytes;
        _receiptBase64 = base64String;
        _receiptFileName = image.name;
      });

      // Animate receipt appearance
      _receiptAnimationController.forward();

      _showSuccessSnackBar(
        'Receipt image processed successfully (${(compressedBytes.length / 1024).toStringAsFixed(1)} KB)',
      );

      debugPrint('✅ Image processed successfully:');
      debugPrint('   - Compressed size: ${compressedBytes.length} bytes');
      debugPrint('   - Base64 length: ${base64String.length} characters');
    } catch (e) {
      debugPrint('❌ Error processing image: $e');
      _showErrorSnackBar('Error processing image: ${e.toString()}');
    }
  }

  /// Main compression function - this is where the magic happens
  Future<Uint8List> _compressImageBytes(Uint8List bytes) async {
    debugPrint('🔄 Starting image compression...');

    // If already small enough, return as-is
    if (bytes.length <= _maxFileSizeBytes) {
      debugPrint('✅ Image already small enough, no compression needed');
      return bytes;
    }

    try {
      img.Image? image = img.decodeImage(bytes);
      if (image == null) {
        throw 'Invalid image format';
      }

      debugPrint('Original dimensions: ${image.width}x${image.height}');

      // Calculate new dimensions while maintaining aspect ratio
      int newWidth = image.width;
      int newHeight = image.height;

      // Resize if too large
      if (newWidth > _maxImageDimension || newHeight > _maxImageDimension) {
        double ratio = newWidth / newHeight;
        if (newWidth > newHeight) {
          newWidth = _maxImageDimension;
          newHeight = (newWidth / ratio).round();
        } else {
          newHeight = _maxImageDimension;
          newWidth = (newHeight * ratio).round();
        }

        debugPrint('Resizing to: ${newWidth}x${newHeight}');
        image = img.copyResize(image, width: newWidth, height: newHeight);
      }

      // Try different quality levels until we get under the target size
      int quality = _compressionQuality;
      Uint8List compressedBytes;

      do {
        compressedBytes = Uint8List.fromList(
          img.encodeJpg(image, quality: quality),
        );
        debugPrint('Quality $quality: ${compressedBytes.length} bytes');

        if (compressedBytes.length <= _maxFileSizeBytes) {
          break;
        }

        quality -= 10;
      } while (quality > 10);

      debugPrint(
        '✅ Final compressed size: ${compressedBytes.length} bytes with quality $quality',
      );
      return compressedBytes;
    } catch (e) {
      debugPrint('❌ Compression failed: $e');
      // Fallback to simple size reduction
      return _fallbackCompress(bytes);
    }
  }

  Future<Uint8List> _fallbackCompress(Uint8List bytes) async {
    debugPrint('Using emergency fallback compression');

    // Just truncate to max size as last resort
    if (bytes.length > _maxFileSizeBytes) {
      _showWarningDialog(
        'Compression Warning',
        'Image had to be heavily compressed. Quality may be reduced. '
            'For better results, please use a smaller image or take a new photo.',
      );

      return Uint8List.fromList(bytes.take(_maxFileSizeBytes).toList());
    }

    return bytes;
  }

  void _showWarningDialog(String title, String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
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

    // Animate removal
    _receiptAnimationController.reverse().then((_) {
      setState(() {
        _receiptImageBytes = null;
        _receiptBase64 = null;
        _receiptFileName = null;
      });
    });

    HapticFeedback.lightImpact();
    debugPrint('🗑️ REMOVE: All image data cleared');
  }

  bool _hasReceiptImage() {
    return _receiptBase64 != null && _receiptBase64!.isNotEmpty;
  }

  Future<void> _submitExpense() async {
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.heavyImpact();
      return;
    }

    // Check if receipt is provided
    if (!_hasReceiptImage()) {
      HapticFeedback.heavyImpact();
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
        HapticFeedback.mediumImpact();
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
    return '₱${amount.toStringAsFixed(2)}';
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
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Section
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    builder:
                        (context, value, child) => Transform.scale(
                          scale: value,
                          child: Container(
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                        ),
                  ),

                  const SizedBox(height: 24),

                  // Budget Summary Card
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder:
                        (context, value, child) => Transform.translate(
                          offset: Offset(0, 20 * (1 - value)),
                          child: Opacity(
                            opacity: value,
                            child: Card(
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
                                            remainingAmount >= 0
                                                ? Colors.green
                                                : Colors.red,
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
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: Colors.red[200]!,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.warning,
                                              color: Colors.red[700],
                                            ),
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
                          ),
                        ),
                  ),

                  const SizedBox(height: 24),

                  // Expense Details Card
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    builder:
                        (context, value, child) => Transform.translate(
                          offset: Offset(0, 20 * (1 - value)),
                          child: Opacity(
                            opacity: value,
                            child: Card(
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
                                      focusNode: _descriptionFocus,
                                      decoration: AppTheme.inputDecoration(
                                        labelText: 'Expense Description',
                                        hintText:
                                            'Enter a detailed description of the expense',
                                        prefixIcon: Icons.description,
                                      ),
                                      maxLines: 3,
                                      textInputAction: TextInputAction.next,
                                      onFieldSubmitted: (_) {
                                        FocusScope.of(
                                          context,
                                        ).requestFocus(_amountFocus);
                                      },
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
                                      focusNode: _amountFocus,
                                      decoration: AppTheme.inputDecoration(
                                        labelText: 'Expense Amount',
                                        hintText:
                                            'Enter expense amount (e.g., 125.50)',
                                        prefixIcon: Icons.attach_money,
                                      ),
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      textInputAction: TextInputAction.done,
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
                                          return 'Expense amount cannot exceed ₱1,000,000';
                                        }

                                        return null;
                                      },
                                    ),

                                    // Amount Warning
                                    if (_currentAmount != null) ...[
                                      const SizedBox(height: 8),
                                      AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
                                        child: Builder(
                                          builder: (context) {
                                            if (_currentAmount! >
                                                    remainingAmount &&
                                                remainingAmount > 0) {
                                              return Container(
                                                padding: const EdgeInsets.all(
                                                  8,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.orange[50],
                                                  borderRadius:
                                                      BorderRadius.circular(6),
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
                                                        'This expense exceeds the remaining budget by ${_formatCurrency(_currentAmount! - remainingAmount)}',
                                                        style: TextStyle(
                                                          color:
                                                              Colors
                                                                  .orange[700],
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
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                  ),

                  const SizedBox(height: 24),

                  // Receipt Upload Card (Required)
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder:
                        (context, value, child) => Transform.translate(
                          offset: Offset(0, 20 * (1 - value)),
                          child: Opacity(
                            opacity: value,
                            child: Card(
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
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
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
                                      'Upload a photo or scan of your receipt for verification. Images will be compressed to fit storage requirements.',
                                      style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    if (!_hasReceiptImage()) ...[
                                      // Upload Button
                                      GestureDetector(
                                        onTap:
                                            _isProcessingImage
                                                ? null
                                                : _pickImage,
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 200,
                                          ),
                                          width: double.infinity,
                                          height: 120,
                                          decoration: BoxDecoration(
                                            color:
                                                _isProcessingImage
                                                    ? Colors.grey[100]
                                                    : Colors.red[50],
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
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
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        CircularProgressIndicator(),
                                                        SizedBox(height: 8),
                                                        Text(
                                                          'Processing image...',
                                                        ),
                                                      ],
                                                    ),
                                                  )
                                                  : Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Icon(
                                                        kIsWeb
                                                            ? Icons.upload_file
                                                            : (Platform
                                                                    .isAndroid ||
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
                                                            : (Platform
                                                                    .isAndroid ||
                                                                Platform.isIOS)
                                                            ? 'Tap to capture receipt'
                                                            : 'Click to select receipt',
                                                        style: TextStyle(
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          color:
                                                              Colors.red[700],
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        'JPG, PNG • Auto-compressed',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color:
                                                              AppTheme
                                                                  .textSecondary,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                        ),
                                      ),
                                    ] else ...[
                                      // Image Preview
                                      ScaleTransition(
                                        scale: _receiptScaleAnimation,
                                        child: Container(
                                          width: double.infinity,
                                          height: 200,
                                          decoration: BoxDecoration(
                                            color: Colors.grey[50],
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: Colors.green[300]!,
                                            ),
                                          ),
                                          child: Stack(
                                            children: [
                                              Center(
                                                child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  child:
                                                      _receiptImageBytes != null
                                                          ? Image.memory(
                                                            _receiptImageBytes!,
                                                            width:
                                                                double.infinity,
                                                            height:
                                                                double.infinity,
                                                            fit: BoxFit.cover,
                                                            errorBuilder: (
                                                              context,
                                                              error,
                                                              stackTrace,
                                                            ) {
                                                              return Container(
                                                                width:
                                                                    double
                                                                        .infinity,
                                                                height:
                                                                    double
                                                                        .infinity,
                                                                color:
                                                                    Colors
                                                                        .grey[200],
                                                                child: const Column(
                                                                  mainAxisAlignment:
                                                                      MainAxisAlignment
                                                                          .center,
                                                                  children: [
                                                                    Icon(
                                                                      Icons
                                                                          .receipt,
                                                                      size: 64,
                                                                      color:
                                                                          Colors
                                                                              .grey,
                                                                    ),
                                                                    SizedBox(
                                                                      height: 8,
                                                                    ),
                                                                    Text(
                                                                      'Receipt Image Attached',
                                                                      style: TextStyle(
                                                                        color:
                                                                            Colors.grey,
                                                                        fontWeight:
                                                                            FontWeight.w500,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              );
                                                            },
                                                          )
                                                          : Container(
                                                            width:
                                                                double.infinity,
                                                            height:
                                                                double.infinity,
                                                            color:
                                                                Colors
                                                                    .grey[200],
                                                            child: const Column(
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment
                                                                      .center,
                                                              children: [
                                                                Icon(
                                                                  Icons.receipt,
                                                                  size: 64,
                                                                  color:
                                                                      Colors
                                                                          .grey,
                                                                ),
                                                                SizedBox(
                                                                  height: 8,
                                                                ),
                                                                Text(
                                                                  'Receipt Image Attached',
                                                                  style: TextStyle(
                                                                    color:
                                                                        Colors
                                                                            .grey,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w500,
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
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          20,
                                                        ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black
                                                            .withOpacity(0.1),
                                                        blurRadius: 4,
                                                        offset: const Offset(
                                                          0,
                                                          2,
                                                        ),
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
                                              'Receipt attached: ${_receiptFileName ?? 'receipt_image'} (${(_receiptImageBytes?.length ?? 0 / 1024).toStringAsFixed(1)} KB)',
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
                                          foregroundColor:
                                              AppTheme.primaryColor,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
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
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 1000),
                    curve: Curves.easeOutCubic,
                    builder:
                        (context, value, child) => Transform.translate(
                          offset: Offset(0, 20 * (1 - value)),
                          child: Opacity(
                            opacity: value,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.blue[200]!),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: Colors.blue[700],
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                          '• Images are automatically compressed for storage\n'
                                          '• Once submitted, the expense will be in "Pending" status\n'
                                          '• Budget Managers will review and approve the expense\n'
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
                          ),
                        ),
                  ),
                ],
              ),
            ),
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
