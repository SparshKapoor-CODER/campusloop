import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'theme.dart';

class MadeByCredit extends StatelessWidget {
  const MadeByCredit({super.key});

  static const _url = 'https://www.linkedin.com/in/sparsh-kapoor-sk/';

  Future<void> _open(BuildContext context) async {
    final uri = Uri.parse(_url);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Could not open link')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Could not open link')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => _open(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
          child: RichText(
            text: const TextSpan(
              children: [
                TextSpan(
                  text: 'Made by ',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                TextSpan(
                  text: 'Sparsh Kapoor',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.accent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}