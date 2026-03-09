import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../services/supabase_service.dart';
import '../config/app_constants.dart';
import '../api/post_sanitizer.dart';
import '../api/post_service.dart';

enum PostType { general, article, event }

/// Create Post Dialog
class CreatePostDialog extends StatefulWidget {
  final VoidCallback? onPostCreated;
  final bool isFullScreen;
  final PostType postType;

  const CreatePostDialog({
    super.key,
    this.onPostCreated,
    this.isFullScreen = false,
    this.postType = PostType.general,
  });

  @override
  State<CreatePostDialog> createState() => _CreatePostDialogState();
}

class _CreatePostDialogState extends State<CreatePostDialog> {
  final _contentController = TextEditingController();
  final _titleController = TextEditingController();
  final _venueController = TextEditingController();
  final _dateController = TextEditingController();
  final _timeController = TextEditingController();
  
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  
  Uint8List? _imageBytes;
  String? _imageName;

  String? _targetDomain;
  String? _myDomain;
  String? _domainError;
  String? _contentError; // caution message from sanitizer

  @override
  void initState() {
    super.initState();
    if (widget.postType == PostType.event) {
      _dateController.text = "${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}";
      _timeController.text = "12:00 PM";
    }
    _loadMyDomain();
  }

  Future<void> _loadMyDomain() async {
    final profile = await SupabaseService.getCurrentUserProfile();
    if (mounted && profile != null) {
      setState(() {
        _myDomain = profile['domain_id'] as String?;
        // No longer pre-selecting _targetDomain = _myDomain
        // This forces the user to choose intentionally.
      });
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    _titleController.dispose();
    _venueController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true, // Crucial for Web binary handling
      );

      if (result != null && result.files.single.bytes != null) {
        Uint8List bytes = result.files.single.bytes!;
        String name = result.files.single.name;
        
        // Heavy Compression Check (>5MB)
        if (bytes.length > 5 * 1024 * 1024) {
          bytes = await _compressImage(bytes);
        }

        setState(() {
          _imageBytes = bytes;
          _imageName = name;
        });
      }
    } catch (e) {
      _showErrorSnackBar('Error picking image: $e');
    }
  }

  Future<Uint8List> _compressImage(Uint8List bytes) async {
    // Note: Quality 80 provides a good balance between size and detail.
    final compressed = await FlutterImageCompress.compressWithList(
      bytes,
      minWidth: 1200,
      minHeight: 1200,
      quality: 80,
    );
    return compressed;
  }

  void _removeImage() {
    setState(() {
      _imageBytes = null;
      _imageName = null;
    });
  }

  Future<void> _createPost() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_targetDomain == null) {
      setState(() => _domainError = 'Please select a domain/audience for your post');
      return;
    }
    setState(() => _domainError = null);

    setState(() {
      _isLoading = true;
    });

    try {
      // ── Smart Clean: sanitize & validate ──────────────────────────
      final result = PostSanitizer.processPostContent(_contentController.text);
      if (!result.isValid) {
        setState(() {
          _contentError = result.error;
          _isLoading = false;
        });
        return;
      }
      setState(() => _contentError = null);

      String? imageUrl;

      // 1. Upload image if selected
      if (_imageBytes != null && _imageName != null) {
        final ext = _imageName!.split('.').last.toLowerCase();
        imageUrl = await PostService.uploadPostImage(
          bytes: _imageBytes!,
          extension: ext,
        );
      }

      String finalContent = result.cleaned; // use sanitized content

      if (widget.postType == PostType.article) {
        finalContent = "ARTICLE_TITLE: ${_titleController.text}\n\n$finalContent";
      } else if (widget.postType == PostType.event) {
        finalContent = "EVENT_TITLE: ${_titleController.text}\nVENUE: ${_venueController.text}\nDATE: ${_dateController.text}\nTIME: ${_timeController.text}\n\n$finalContent";
      }

      // 2. Create post with image URL and target domain
      await SupabaseService.createPost(
        content: finalContent,
        imageUrl: imageUrl,
        targetDomainId: _targetDomain,
      );

      if (mounted) {
        if (!widget.isFullScreen) {
          Navigator.of(context).pop();
        } else {
          _contentController.clear();
          _titleController.clear();
          _venueController.clear();
          _removeImage();
        }
        widget.onPostCreated?.call();
        _showSuccessSnackBar('Post created successfully!');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error creating post: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue[700],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildDomainPicker() {
    final domains = AppConstants.domains;
    final domainColors = AppConstants.domainColors;
    final domainIcons = AppConstants.domainIcons;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.public, size: 15, color: Colors.grey[600]),
            const SizedBox(width: 6),
            Text(
              'Post audience domain',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[700]),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: domains.map((domain) {
            final isSelected = _targetDomain == domain;
            final isMyDomain = domain == _myDomain;
            final domainColor = domainColors[domain] ?? Colors.blue;
            final icon = domainIcons[domain] ?? Icons.work;

            // Green when own domain is selected, domain color for cross-domain
            final selectedColor = (isSelected && isMyDomain)
                ? const Color(0xFF2E7D32) // dark green
                : domainColor;

            return GestureDetector(
              onTap: () => setState(() {
                _targetDomain = domain;
                _domainError = null; // clear error when user picks a domain
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected ? selectedColor.withValues(alpha: 0.12) : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? selectedColor : Colors.grey[350]!,
                    width: isSelected ? 2.0 : 1.0,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 14, color: isSelected ? selectedColor : Colors.grey[500]),
                    const SizedBox(width: 5),
                    Text(
                      domain,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? selectedColor : Colors.grey[600],
                      ),
                    ),
                    if (isMyDomain) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: (isSelected ? const Color(0xFF2E7D32) : Colors.blue).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Mine',
                          style: TextStyle(
                            fontSize: 9,
                            color: isSelected ? const Color(0xFF2E7D32) : Colors.blue[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );

          }).toList(),
        ),
        if (_targetDomain != null && _targetDomain != _myDomain)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 13, color: Colors.orange[700]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'This post will appear in the $_targetDomain feed, not your own domain.',
                    style: TextStyle(fontSize: 11, color: Colors.orange[700], fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    String titleText = 'Create Post';
    if (widget.postType == PostType.article) titleText = 'Write Article';
    if (widget.postType == PostType.event) titleText = 'Create Event';

    final content = Padding(
      padding: EdgeInsets.all(widget.isFullScreen ? 20 : 24),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header (only for dialog)
              if (!widget.isFullScreen)
                Row(
                  children: [
                    Icon(
                      widget.postType == PostType.article ? Icons.article : (widget.postType == PostType.event ? Icons.calendar_month : Icons.create),
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      titleText,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              if (!widget.isFullScreen) const SizedBox(height: 16),
              
              // Article/Event Title field
              if (widget.postType != PostType.general) ...[
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    hintText: widget.postType == PostType.article ? 'Article Title' : 'Event Title',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.title),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],

              // Event Specific Fields
              if (widget.postType == PostType.event) ...[
                TextFormField(
                  controller: _venueController,
                  decoration: InputDecoration(
                    hintText: 'Venue',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.location_on),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a venue';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _dateController,
                        readOnly: true,
                        decoration: InputDecoration(
                          hintText: 'Date',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.calendar_today),
                        ),
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date != null) {
                            _dateController.text = "${date.year}-${date.month}-${date.day}";
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _timeController,
                        readOnly: true,
                        decoration: InputDecoration(
                          hintText: 'Time',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.access_time),
                        ),
                        onTap: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.now(),
                          );
                          if (time != null) {
                            _timeController.text = time.format(context);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // ── Content field with simple counter ────────────────
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _contentController,
                builder: (context, value, _) {
                  final len  = value.text.length;
                  final minL = AppConstants.minPostLength;
                  final maxL = AppConstants.maxPostLength;

                  final String counterLabel = len < minL
                      ? '$len / min $minL'
                      : '$len chars';

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _contentController,
                        decoration: InputDecoration(
                          hintText: widget.postType == PostType.article
                              ? 'Article body...'
                              : (widget.postType == PostType.event
                                  ? 'Event description...'
                                  : "What's on your mind?"),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          counterText: '', // hide built-in counter
                        ),
                        maxLines: widget.postType == PostType.article ? 15 : 12,
                        maxLength: maxL,
                        textInputAction: TextInputAction.newline,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter some content';
                          }
                          return null;
                        },
                        onChanged: (_) => setState(() => _contentError = null),
                      ),
                      // Simple plain counter
                      Padding(
                        padding: const EdgeInsets.only(top: 4, right: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              counterLabel,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // ── Caution banner ─────────────────────────
                      if (_contentError != null)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            border: Border.all(color: Colors.amber.shade400),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, size: 16, color: Colors.amber.shade800),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _contentError!,
                                  style: TextStyle(
                                    color: Colors.amber.shade900,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),

              // ── Target Domain Picker ────────────────────────────
              _buildDomainPicker(),
              const SizedBox(height: 12),

              // Image Preview
              if (_imageBytes != null) ...[
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.memory(
                          _imageBytes!,
                          width: double.infinity,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                          gaplessPlayback: true,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: _removeImage,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).dividerColor.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // Add Image Button
              if (widget.postType != PostType.article) // Hide image button for article if we want "article only" but usually articles have images. Let's keep it optional.
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _pickImage,
                icon: const Icon(Icons.image_outlined),
                label: Text(_imageBytes == null ? 'Add Image' : 'Change Image'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue,
                  side: const BorderSide(color: Colors.blue),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 12),

              // Inline domain error banner
              if (_domainError != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    border: Border.all(color: Colors.red.shade300),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, size: 16, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _domainError!,
                          style: TextStyle(color: Colors.red.shade700, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),

              // Submit Button
              ElevatedButton(
                onPressed: _isLoading ? null : _createPost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        widget.postType == PostType.general ? 'Post' : (widget.postType == PostType.article ? 'Publish' : 'Create Event'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );

    if (widget.isFullScreen) {
      return Stack(
        children: [
          // Background SVG
          Positioned.fill(
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor, // Replaces Color(0xFFF8F9FB)
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Opacity(
                    opacity: 0.9,
                    child: SvgPicture.asset(
                      'assets/svg/undraw_post_eok2.svg',
                      fit: BoxFit.contain,
                      width: MediaQuery.of(context).size.width * 0.85,
                      height: MediaQuery.of(context).size.height * 0.85,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor.withOpacity(0.8),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1A2740).withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: content,
            ),
          ),
        ],
      );
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Background SVG
            Positioned.fill(
              child: Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: Align(
                  alignment: Alignment.center,
                  child: Opacity(
                    opacity: 0.9,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: SvgPicture.asset(
                        'assets/svg/undraw_post_eok2.svg',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor.withOpacity(0.8),
                borderRadius: BorderRadius.circular(16),
              ),
              child: content,
            ),
          ],
        ),
      ),
    );
  }
}
