import 'package:flutter/material.dart';
import '../services/email_service.dart';

/// A simple, themed screen to test the [EmailService].
class EmailSenderScreen extends StatefulWidget {
  const EmailSenderScreen({Key? key}) : super(key: key);

  @override
  State<EmailSenderScreen> createState() => _EmailSenderScreenState();
}

class _EmailSenderScreenState extends State<EmailSenderScreen> {
  final _recipientController = TextEditingController();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  bool _isSending = false;

  @override
  void dispose() {
    _recipientController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _handleSendEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSending = true);

    final success = await EmailService.sendEmail(
      recipientEmail: _recipientController.text.trim(),
      subject: _subjectController.text.trim(),
      body: _messageController.text.trim(),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Email sent successfully!' : 'Failed to send email. Check your SMTP configuration.',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: success ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      setState(() => _isSending = false);
      if (success) {
        // Clear fields on success
        _subjectController.clear();
        _messageController.clear();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Direct Email Sender'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Icon(Icons.email_outlined, size: 64, color: theme.primaryColor),
              const SizedBox(height: 16),
              const Text(
                'Send direct emails using Gmail SMTP.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 32),

              // Recipient Field
              _buildTextField(
                controller: _recipientController,
                label: 'Recipient Email',
                hint: 'example@gmail.com',
                icon: Icons.person_outline,
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Please enter recipient email';
                  if (!val.contains('@')) return 'Please enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Subject Field
              _buildTextField(
                controller: _subjectController,
                label: 'Subject',
                hint: 'Your Email Subject',
                icon: Icons.subject,
                validator: (val) => (val == null || val.isEmpty) ? 'Please enter a subject' : null,
              ),
              const SizedBox(height: 20),

              // Message Field
              _buildTextField(
                controller: _messageController,
                label: 'Message',
                hint: 'Write your message here...',
                icon: Icons.message_outlined,
                maxLines: 6,
                validator: (val) => (val == null || val.isEmpty) ? 'Please enter a message' : null,
              ),
              const SizedBox(height: 32),

              // Send Button
              ElevatedButton(
                onPressed: _isSending ? null : _handleSendEmail,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                child: _isSending
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Send Email',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
              const SizedBox(height: 20),
              
              // Note for user
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: theme.primaryColor),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'This screen uses your Gmail App Password from .env to send emails directly via SMTP.',
                        style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 20),
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            errorStyle: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
