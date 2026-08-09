import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/theme.dart';

/// In-app Privacy Policy + Terms of Service. Aligns with Zambia's Data
/// Protection Act (2021), Google Play's data-safety requirements, and names
/// the operating business (Carpso Solutions) as the data controller.
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy & terms')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section(
            theme,
            LucideIcons.building2,
            'Who operates Kingdom Sponsor',
            'Kingdom Sponsor is operated by Carpso Solutions, a registered business in Zambia. '
            'The service connects donors with verified campaign hosts and processes donations '
            'through licensed mobile-money partners (Lipila).',
          ),
          _section(
            theme,
            LucideIcons.database,
            'What data we collect',
            'Phone number (to sign in, send payment prompts and SMS receipts), your chosen '
            'display name, campaign details you create, donation history, referral data, '
            'linked-account relationships, device tokens (for push notifications) and basic '
            'technical logs (IP address, device info) for security and fraud prevention.',
          ),
          _section(
            theme,
            LucideIcons.lock,
            'How we use and protect it',
            'Your data is used only to run the service: process donations, send receipts and '
            'alerts, verify hosts, and keep the platform safe. Passwords and OTPs are stored '
            'hashed. Payments are handled by our licensed payment partner — card numbers never '
            'touch our servers. We never sell your personal data.',
          ),
          _section(
            theme,
            LucideIcons.shieldCheck,
            'Your rights',
            'You can request a copy of your data, correct it, or delete your account at any '
            'time from Settings > Delete account (financial records are retained anonymously '
            'for legal and tax compliance). To exercise any right, contact the administrator '
            'through Help & support.',
          ),
          _section(
            theme,
            LucideIcons.phone,
            'Your number & donations',
            'Your phone number is used for mobile-money payment prompts and is never displayed '
            'publicly on the platform. Donation amounts and donor names appear publicly unless '
            'you choose to give anonymously or hide your amount.',
          ),
          _section(
            theme,
            LucideIcons.fileText,
            'Terms of service',
            'By using Kingdom Sponsor you agree to give honestly, host campaigns truthfully, '
            'and not use the platform for fraud, illegal fundraising, or anything harmful. '
            'Campaign hosts are responsible for how they use raised funds. The platform may '
            'remove campaigns and accounts that violate these terms. Donations are generally '
            'non-refundable; promotional fees may be refunded at our discretion.',
          ),
          _section(
            theme,
            LucideIcons.calendar,
            'Updates to this policy',
            'We may update this policy as the service grows. Significant changes will be '
            'announced in the app. Continued use after changes means you accept them.',
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Last updated: August 2026 · Carpso Solutions, Zambia',
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(ThemeData theme, IconData icon, String title, String body) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(body, style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
          ],
        ),
      ),
    );
  }
}
