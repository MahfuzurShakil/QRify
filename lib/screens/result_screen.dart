import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../models/history_item.dart';
import '../widgets/common_widgets.dart';

// ─── URL launcher ─────────────────────────────────────────────────────────────
Future<void> _launchUrlExternal(BuildContext context, String url) async {
  try {
    String finalUrl = url;
    if (!url.startsWith('http://') &&
        !url.startsWith('https://') &&
        !url.startsWith('mailto:') &&
        !url.startsWith('tel:') &&
        !url.startsWith('sms:')) {
      finalUrl = 'https://$url';
    }
    final uri = Uri.parse(finalUrl);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      showAppToast(context, 'No app found to open this', type: ToastType.error);
    }
  } catch (e) {
    if (context.mounted) {
      showAppToast(context, 'Could not open: $url', type: ToastType.error);
    }
  }
}

// ─── vCard → Android Contacts app ────────────────────────────────────────────
Future<void> _addContact(BuildContext context, String vcard) async {
  final name = QrPayload.vcardField(vcard, 'FN');
  final phone = QrPayload.vcardField(vcard, 'TEL');
  final email = QrPayload.vcardField(vcard, 'EMAIL');

  bool launched = false;

  // Correct Android INSERT contact intent URI
  // android.intent.action.INSERT with type vnd.android.cursor.dir/contact
  try {
    final parts = <String>[
      'action=android.intent.action.INSERT',
      'type=vnd.android.cursor.dir%2Fcontact',
    ];
    if (name.isNotEmpty) parts.add('name=${Uri.encodeComponent(name)}');
    if (phone.isNotEmpty) parts.add('phone=${Uri.encodeComponent(phone)}');
    if (email.isNotEmpty) parts.add('email=${Uri.encodeComponent(email)}');
    parts.add('end');

    // intent: scheme format that Android understands
    final intentUri = Uri.parse('intent:#Intent;${parts.join(';')}');
    launched = await launchUrl(intentUri, mode: LaunchMode.externalApplication);
  } catch (_) {}

  // Fallback: direct contacts provider URI
  if (!launched) {
    try {
      final uri = Uri.parse('content://com.android.contacts/contacts');
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  // শেষ fallback: dialog দিয়ে manually copy করতে দাও
  if (!launched && context.mounted) {
    _showContactDialog(context, name, phone, email);
  }
}

void _showContactDialog(
    BuildContext context, String name, String phone, String email) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: context.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: context.borderColor, width: 0.5),
      ),
      title: Text('Add Contact',
          style: TextStyle(color: context.txtPrimary, fontSize: 16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tap any field to copy, then add manually to Contacts app.',
            style: TextStyle(fontSize: 12, color: context.txtMuted),
          ),
          const SizedBox(height: 12),
          if (name.isNotEmpty) _ContactInfoTile(label: 'Name', value: name),
          if (phone.isNotEmpty) _ContactInfoTile(label: 'Phone', value: phone),
          if (email.isNotEmpty) _ContactInfoTile(label: 'Email', value: email),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child:
              const Text('Close', style: TextStyle(color: AppColors.primary)),
        ),
      ],
    ),
  );
}

// ─── Result Screen (StatefulWidget — Save button state update এর জন্য) ─────────
class ResultScreen extends StatefulWidget {
  final HistoryItem item;
  const ResultScreen({super.key, required this.item});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  Color get _primaryColor {
    switch (widget.item.scanType) {
      case ScanType.qrCode:
        return widget.item.actionType == ActionType.scanned
            ? AppColors.primary
            : AppColors.accent;
      case ScanType.barcode:
        return widget.item.actionType == ActionType.scanned
            ? AppColors.success
            : AppColors.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgDeep,
      appBar: AppBar(
        title: Text(
          widget.item.actionType == ActionType.scanned
              ? 'Scan Result'
              : 'Generated',
        ),
        leadingWidth: 54,
        leading: const AppBackButton(),
        actions: const [],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Success icon ────────────────────────────────────────
            Center(
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: _primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: _primaryColor.withOpacity(0.3), width: 1),
                    ),
                    child: Icon(
                      widget.item.actionType == ActionType.scanned
                          ? Icons.check_rounded
                          : Icons.auto_awesome_rounded,
                      color: _primaryColor,
                      size: 32,
                    ),
                  )
                      .animate()
                      .scale(
                          begin: const Offset(0, 0),
                          curve: Curves.easeOutBack,
                          duration: 500.ms)
                      .fadeIn(),
                  const SizedBox(height: 12),
                  Text(
                    widget.item.actionType == ActionType.scanned
                        ? 'Scan Successful'
                        : 'Generated Successfully',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: context.txtPrimary,
                    ),
                  ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.2),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TypeBadge(
                        label: widget.item.scanType == ScanType.qrCode
                            ? 'QR Code'
                            : 'Barcode',
                        color: _primaryColor,
                      ),
                      if (widget.item.barcodeFormat != null) ...[
                        const SizedBox(width: 6),
                        TypeBadge(
                            label: widget.item.barcodeFormat!,
                            color: context.txtMuted),
                      ],
                    ],
                  ).animate(delay: 300.ms).fadeIn(),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ─── Content card ────────────────────────────────────────
            GlassContainer(
              borderColor: _primaryColor.withOpacity(0.15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _CategoryIcon(
                          category: widget.item.category, color: _primaryColor),
                      const SizedBox(width: 10),
                      Text(
                        _categoryLabel(widget.item.category),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    widget.item.content,
                    style: TextStyle(
                      fontSize: 14,
                      color: context.txtPrimary,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ).animate(delay: 350.ms).fadeIn().slideY(begin: 0.1),

            const SizedBox(height: 16),

            // ─── Smart actions ───────────────────────────────────────
            ..._buildSmartActions(context),

            // ─── Quick actions: Copy | Share (Save সরানো হয়েছে) ───────
            Row(
              children: [
                Expanded(
                  child: _QuickAction(
                    icon: Icons.content_copy_rounded,
                    label: 'Copy',
                    onTap: () {
                      Clipboard.setData(
                          ClipboardData(text: widget.item.content));
                      showAppToast(context, 'Copied to clipboard!',
                          type: ToastType.success);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.share_rounded,
                    label: 'Share',
                    onTap: () => Share.share(widget.item.content),
                  ),
                ),
              ],
            ).animate(delay: 450.ms).fadeIn().slideY(begin: 0.1),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSmartActions(BuildContext context) {
    final actions = <Widget>[];

    switch (widget.item.category) {
      case ContentCategory.url:
        actions.add(
          SizedBox(
            width: double.infinity,
            child: ActionButton(
              label: 'Open in Browser',
              icon: Icons.open_in_new_rounded,
              onTap: () => _launchUrlExternal(context, widget.item.content),
            ),
          ).animate(delay: 400.ms).fadeIn().slideY(begin: 0.1),
        );
        break;

      case ContentCategory.email:
        actions.add(
          SizedBox(
            width: double.infinity,
            child: ActionButton(
              label: 'Send Email',
              icon: Icons.email_rounded,
              onTap: () => _launchUrlExternal(context, widget.item.content),
              color: AppColors.accent,
            ),
          ).animate(delay: 400.ms).fadeIn().slideY(begin: 0.1),
        );
        break;

      case ContentCategory.phone:
        actions.addAll([
          SizedBox(
            width: double.infinity,
            child: ActionButton(
              label: 'Call Now',
              icon: Icons.phone_rounded,
              onTap: () => _launchUrlExternal(context, widget.item.content),
              color: AppColors.success,
            ),
          ).animate(delay: 400.ms).fadeIn().slideY(begin: 0.1),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ActionButton(
              label: 'Send SMS',
              icon: Icons.sms_rounded,
              onTap: () => _launchUrlExternal(
                context,
                'sms:${widget.item.content.replaceFirst('tel:', '')}',
              ),
              outlined: true,
            ),
          ).animate(delay: 450.ms).fadeIn(),
        ]);
        break;

      case ContentCategory.wifi:
        final ssid = QrPayload.wifiField(widget.item.content, 'S');
        final pass = QrPayload.wifiField(widget.item.content, 'P');
        actions.add(
          GlassContainer(
            borderColor: AppColors.success.withOpacity(0.2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Icon(Icons.wifi_rounded, color: AppColors.success, size: 16),
                  SizedBox(width: 8),
                  Text('WiFi Details',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.success)),
                ]),
                const SizedBox(height: 12),
                _InfoRow(label: 'Network', value: ssid),
                const SizedBox(height: 8),
                if (pass.isNotEmpty)
                  _InfoRow(label: 'Password', value: pass, isPassword: true)
                else
                  const _InfoRow(label: 'Password', value: 'Open network'),
              ],
            ),
          ).animate(delay: 400.ms).fadeIn().slideY(begin: 0.1),
        );
        break;

      case ContentCategory.contact:
        final name = QrPayload.vcardField(widget.item.content, 'FN');
        final phone = QrPayload.vcardField(widget.item.content, 'TEL');
        final email = QrPayload.vcardField(widget.item.content, 'EMAIL');
        actions.addAll([
          GlassContainer(
            borderColor: AppColors.accent.withOpacity(0.2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Icon(Icons.person_rounded, color: AppColors.accent, size: 16),
                  SizedBox(width: 8),
                  Text('Contact',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accent)),
                ]),
                const SizedBox(height: 12),
                if (name.isNotEmpty) _InfoRow(label: 'Name', value: name),
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _InfoRow(label: 'Phone', value: phone),
                ],
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _InfoRow(label: 'Email', value: email),
                ],
              ],
            ),
          ).animate(delay: 400.ms).fadeIn().slideY(begin: 0.1),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ActionButton(
              label: 'Add to Contacts',
              icon: Icons.person_add_rounded,
              onTap: () => _addContact(context, widget.item.content),
              color: AppColors.accent,
            ),
          ).animate(delay: 450.ms).fadeIn(),
        ]);
        break;

      case ContentCategory.sms:
        // SMSTO:number:message → sms:number?body=message
        final rest = widget.item.content
            .replaceFirst(RegExp(r'^(smsto|sms):', caseSensitive: false), '');
        final idx = rest.indexOf(':');
        final number = idx == -1 ? rest : rest.substring(0, idx);
        final body = idx == -1 ? '' : rest.substring(idx + 1);
        actions.add(
          SizedBox(
            width: double.infinity,
            child: ActionButton(
              label: 'Send SMS',
              icon: Icons.sms_rounded,
              onTap: () => _launchUrlExternal(
                context,
                body.isEmpty
                    ? 'sms:$number'
                    : 'sms:$number?body=${Uri.encodeComponent(body)}',
              ),
              color: AppColors.success,
            ),
          ).animate(delay: 400.ms).fadeIn().slideY(begin: 0.1),
        );
        break;

      default:
        break;
    }

    if (actions.isEmpty) return [];
    return [...actions, const SizedBox(height: 16)];
  }

  String _categoryLabel(ContentCategory cat) {
    switch (cat) {
      case ContentCategory.url:
        return 'Website URL';
      case ContentCategory.email:
        return 'Email Address';
      case ContentCategory.phone:
        return 'Phone Number';
      case ContentCategory.wifi:
        return 'WiFi Network';
      case ContentCategory.contact:
        return 'Contact Card';
      case ContentCategory.sms:
        return 'SMS Message';
      case ContentCategory.barcode:
        return 'Barcode';
      default:
        return 'Plain Text';
    }
  }
}

// ─── Category Icon ────────────────────────────────────────────────────────────
class _CategoryIcon extends StatelessWidget {
  final ContentCategory category;
  final Color color;
  const _CategoryIcon({required this.category, required this.color});

  IconData get _icon {
    switch (category) {
      case ContentCategory.url:
        return Icons.link_rounded;
      case ContentCategory.email:
        return Icons.email_rounded;
      case ContentCategory.phone:
        return Icons.phone_rounded;
      case ContentCategory.wifi:
        return Icons.wifi_rounded;
      case ContentCategory.contact:
        return Icons.person_rounded;
      case ContentCategory.sms:
        return Icons.sms_rounded;
      case ContentCategory.barcode:
        return Icons.qr_code_rounded;
      default:
        return Icons.text_snippet_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(_icon, color: color, size: 15),
    );
  }
}

// ─── Quick Action Button ──────────────────────────────────────────────────────
class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: context.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.borderColor, width: 0.5),
        ),
        child: Column(
          children: [
            Icon(icon, color: context.txtSecondary, size: 20),
            const SizedBox(height: 5),
            Text(label,
                style: TextStyle(fontSize: 11, color: context.txtSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

// ─── Info Row ────────────────────────────────────────────────────────────────
class _InfoRow extends StatefulWidget {
  final String label;
  final String value;
  final bool isPassword;
  const _InfoRow(
      {required this.label, required this.value, this.isPassword = false});

  @override
  State<_InfoRow> createState() => _InfoRowState();
}

class _InfoRowState extends State<_InfoRow> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(widget.label,
              style: TextStyle(fontSize: 12, color: context.txtMuted)),
        ),
        Expanded(
          child: Text(
            widget.isPassword && _obscure
                ? '•' * widget.value.length.clamp(0, 12)
                : widget.value,
            style: TextStyle(
                fontSize: 13,
                color: context.txtPrimary,
                fontWeight: FontWeight.w500),
          ),
        ),
        if (widget.isPassword)
          GestureDetector(
            onTap: () => setState(() => _obscure = !_obscure),
            child: Icon(
              _obscure
                  ? Icons.visibility_rounded
                  : Icons.visibility_off_rounded,
              color: context.txtMuted,
              size: 16,
            ),
          ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: widget.value));
            showAppToast(context, '${widget.label} copied!',
                type: ToastType.success);
          },
          child: Icon(Icons.content_copy_rounded,
              color: context.txtMuted, size: 15),
        ),
      ],
    );
  }
}

// ─── Contact Info Tile (Dialog) ───────────────────────────────────────────────
class _ContactInfoTile extends StatelessWidget {
  final String label;
  final String value;
  const _ContactInfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 55,
            child: Text(label,
                style: TextStyle(fontSize: 12, color: context.txtMuted)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontSize: 13,
                    color: context.txtPrimary,
                    fontWeight: FontWeight.w500)),
          ),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: value));
              showAppToast(context, '$label copied!', type: ToastType.success);
            },
            child: Icon(Icons.content_copy_rounded,
                color: context.txtMuted, size: 14),
          ),
        ],
      ),
    );
  }
}
