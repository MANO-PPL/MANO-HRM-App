import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class MailService {
  static final MailService _instance = MailService._internal();
  factory MailService() => _instance;
  MailService._internal();

  /// Constants from .env
  String get _emailUser => dotenv.env['EMAIL_USER'] ?? '';
  String get _emailPass => dotenv.env['EMAIL_PASS'] ?? '';
  String get _adminEmails => dotenv.env['ADMIN_EMAIL'] ?? '';

  /// Send Password Reset OTP Email
  Future<bool> sendPasswordResetOtp({
    required String recipientEmail,
    required String otp,
  }) async {
    if (_emailUser.isEmpty || _emailPass.isEmpty) {
      debugPrint('Cannot send email: Missing credentials in .env');
      return false;
    }

    final smtpServer = gmail(_emailUser, _emailPass);

    final message = Message()
      ..from = Address(_emailUser, 'Mano Attention App')
      ..recipients.add(recipientEmail)
      ..subject = 'Password Reset OTP'
      ..text = 'Your OTP for password reset is: $otp'
      ..html = '<h3>Password Reset OTP</h3><p>Your OTP is: <b>$otp</b></p>';

    try {
      final sendReport = await send(message, smtpServer);
      debugPrint('OTP email sent: ${sendReport.toString()}');
      return true;
    } on MailerException catch (e) {
      debugPrint('OTP email not sent.');
      for (var p in e.problems) {
        debugPrint('Problem: ${p.code}: ${p.msg}');
      }
      return false;
    } catch (e) {
      debugPrint('Error sending OTP email: ${e.toString()}');
      return false;
    }
  }

  /// Send Feedback Email
  Future<bool> sendFeedbackEmail({
    required String title,
    required String description,
    required String type,
    List<File>? attachments,
  }) async {
    if (_emailUser.isEmpty || _emailPass.isEmpty) {
      debugPrint('Cannot send email: Missing credentials in .env');
      return false;
    }

    // Configure SMTP server (Gmail)
    final smtpServer = gmail(_emailUser, _emailPass);

    // Create the message
    final message = Message()
      ..from = Address(_emailUser, 'Mano Attention App')
      ..subject = '[$type] $title';

    // Add Recipients
    // 1. Add Admins
    if (_adminEmails.isNotEmpty) {
      final admins = _adminEmails.split(',').map((e) => e.trim()).toList();
      for (var admin in admins) {
         if (admin.isNotEmpty) message.recipients.add(admin);
      }
    }
    // 2. Add Self (Sender) as backup/confirmation if list is empty, or just rely on admins
    if (message.recipients.isEmpty) {
      message.recipients.add(_emailUser);
    }

    message.text = 'Type: $type\n\nTitle: $title\n\nDescription:\n$description';
    message.html = '''
      <h3>New Feedback Received</h3>
      <p><strong>Type:</strong> $type</p>
      <p><strong>Title:</strong> $title</p>
      <p><strong>Description:</strong></p>
      <p>$description</p>
      <br>
      <p><small>Sent from Mano Attention App</small></p>
    ''';

    // Add attachments
    if (attachments != null) {
      for (var file in attachments) {
        message.attachments.add(FileAttachment(file));
      }
    }

    try {
      final sendReport = await send(message, smtpServer);
      debugPrint('Message sent: ${sendReport.toString()}');
      return true;
    } on MailerException catch (e) {
      debugPrint('Message not sent.');
      for (var p in e.problems) {
        debugPrint('Problem: ${p.code}: ${p.msg}');
      }
      return false;
    } catch (e) {
      debugPrint('Error sending email: $e');
      return false;
    }
  }
}
