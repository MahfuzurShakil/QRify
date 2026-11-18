import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import 'dart:io';
import 'dart:ui' as ui;
import '../theme/app_theme.dart';
import '../models/history_item.dart';
import '../widgets/common_widgets.dart';

class QRGeneratorScreen extends StatefulWidget {
  final String initialType;
  const QRGeneratorScreen({super.key, this.initialType = 'URL'});

  @override
  State<QRGeneratorScreen> createState() => _QRGeneratorScreenState();
}

class _QRGeneratorScreenState extends State<QRGeneratorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _previewKey = GlobalKey();
  late String _selectedType;
  String _qrData = '';
  bool _isGenerated = false;
  Color _fgColor = AppColors.darkBgDeep;
  Color _bgColor = AppColors.surfaceWhite;
  bool _isSaving = false;

  final _urlCtrl = TextEditingController();
  final _textCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _ssidCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  String _wifiType = 'WPA';
  bool _wifiHidden = false;

  final List<Map<String, dynamic>> _types = [
    {
      'id': 'URL',
      'label': 'URL',
      'icon': Icons.link_rounded,
      'color': AppColors.primary
    },
    {
      'id': 'Text',
      'label': 'Text',
      'icon': Icons.text_fields_rounded,
      'color': AppColors.warning
    },
    {
      'id': 'Contact',
      'label': 'Contact',
      'icon': Icons.person_rounded,
      'color': AppColors.accent
    },
    {
      'id': 'WiFi',
      'label': 'WiFi',
      'icon': Icons.wifi_rounded,
      'color': AppColors.success
    },
    {
      'id': 'Email',
      'label': 'Email',
      'icon': Icons.email_rounded,
      'color': AppColors.primaryLight
    },
    {
      'id': 'Phone',
      'label': 'Phone',
      'icon': Icons.phone_rounded,
      'color': AppColors.lavender
    },
  ];

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _textCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _ssidCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  static final _schemeRe = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.\-]*://');

  static String _withScheme(String url) =>
      _schemeRe.hasMatch(url) ? url : 'https://$url';

  // WiFi / vCard এ special character escape করতে হয়, না হলে scan ভুল আসে
  static String _escapeWifi(String v) =>
      v.replaceAllMapped(RegExp(r'([\\;,:"])'), (m) => '\\${m[1]}');

  static String _escapeVCard(String v) => v
      .replaceAll('\\', '\\\\')
      .replaceAll(';', '\\;')
      .replaceAll(',', '\\,')
      .replaceAll('\n', '\\n');

  String _buildQRData() {
    switch (_selectedType) {
      case 'URL':
        return _withScheme(_urlCtrl.text.trim());
      case 'Text':
        return _textCtrl.text.trim();
      case 'Contact':
        final name = _escapeVCard(_nameCtrl.text.trim());
        final phone = _phoneCtrl.text.trim();
        final email = _emailCtrl.text.trim();
        return [
          'BEGIN:VCARD',
          'VERSION:3.0',
          'N:;$name;;;',
          'FN:$name',
          if (phone.isNotEmpty) 'TEL:$phone',
          if (email.isNotEmpty) 'EMAIL:$email',
          'END:VCARD',
        ].join('\n');
      case 'WiFi':
        final ssid = _escapeWifi(_ssidCtrl.text.trim());
        if (_wifiType == 'None') {
          return 'WIFI:T:nopass;S:$ssid;${_wifiHidden ? 'H:true;' : ''};';
        }
        final pass = _escapeWifi(_passCtrl.text);
        return 'WIFI:T:$_wifiType;S:$ssid;P:$pass;${_wifiHidden ? 'H:true;' : ''};';
      case 'Email':
        return 'mailto:${_emailCtrl.text.trim()}';
      case 'Phone':
        return 'tel:${_phoneCtrl.text.trim()}';
      default:
        return '';
    }
  }

  static bool _fitsInQr(String data) {
    try {
      QrImage(QrCode.fromData(
        data: data,
        errorCorrectLevel: QrErrorCorrectLevel.H,
      ));
      return true;
    } catch (_) {
      return false;
    }
  }

  void _generate() {
    if (!_formKey.currentState!.validate()) return;
    final data = _buildQRData();
    if (data.isEmpty) return;
    // Keyboard dismiss
    FocusScope.of(context).unfocus();

    // Data QR তে fit না হলে preview তে error image বানাবো না।
    // QrValidator একা যথেষ্ট না — আসল QrImage বানিয়ে দেখতে হয়।
    if (!_fitsInQr(data)) {
      setState(() {
        _isGenerated = false;
        _qrData = '';
      });
      showAppToast(
        context,
        'Text is too long for a QR code. Please shorten it.',
        type: ToastType.error,
      );
      return;
    }

    setState(() {
      _qrData = data;
      _isGenerated = true;
    });
    HistoryService.add(
      content: data,
      scanType: ScanType.qrCode,
      actionType: ActionType.generated,
    );
  }

  Future<void> _saveToGallery() async {
    if (_isSaving) return;
    if (!_isGenerated || _qrData.isEmpty) {
      showAppToast(context, 'Generate a valid QR code first',
          type: ToastType.error);
      return;
    }
    setState(() => _isSaving = true);
    try {
      final boundary = _previewKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        if (mounted) {
          showAppToast(context, 'Could not capture QR code',
              type: ToastType.error);
        }
        return;
      }
      final image = await boundary.toImage(pixelRatio: 4.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/qrify_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);

      final hasAccess = await Gal.hasAccess();
      if (!hasAccess && !await Gal.requestAccess()) {
        if (mounted) {
          showAppToast(context, 'Gallery permission denied',
              type: ToastType.error);
        }
        return;
      }
      await Gal.putImage(file.path, album: 'QRify');

      if (mounted) {
        showAppToast(context, 'QR code saved to gallery!',
            type: ToastType.success);
      }
    } catch (e) {
      if (mounted) {
        showAppToast(context, 'Could not save QR code', type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _share() async {
    if (!_isGenerated || _qrData.isEmpty) return;
    try {
      final boundary = _previewKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/qr_share.png');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)],
          text: 'QR Code generated with QRify');
    } catch (e) {
      if (mounted) {
        showAppToast(context, 'Could not share QR code', type: ToastType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgDeep,
      appBar: AppBar(
        title: const Text('QR Generator'),
        leadingWidth: 54,
        leading: const AppBackButton(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _types.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final t = _types[i];
                    final selected = _selectedType == t['id'];
                    final color = t['color'] as Color;
                    return GestureDetector(
                      onTap: () => setState(() {
                        _selectedType = t['id'];
                        _isGenerated = false;
                      }),
                      child: AnimatedContainer(
                        duration: 200.ms,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: selected
                              ? color.withOpacity(0.15)
                              : context.bgCard,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: selected
                                ? color.withOpacity(0.4)
                                : context.borderColor,
                            width: selected ? 1 : 0.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(t['icon'] as IconData,
                                color: selected ? color : context.txtMuted,
                                size: 14),
                            const SizedBox(width: 6),
                            Text(t['label'],
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: selected ? color : context.txtMuted,
                                )),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ).animate().fadeIn(),
              const SizedBox(height: 24),
              _buildInputFields(),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ActionButton(
                  label: 'Generate QR Code',
                  icon: Icons.qr_code_rounded,
                  onTap: _generate,
                ),
              ),
              if (_isGenerated && _qrData.isNotEmpty) ...[
                const SizedBox(height: 28),
                _QRPreview(
                  data: _qrData,
                  fgColor: _fgColor,
                  bgColor: _bgColor,
                  previewKey: _previewKey,
                  onSave: _saveToGallery,
                  onShare: _share,
                  isSaving: _isSaving,
                  onColorChange: (fg, bg) => setState(() {
                    _fgColor = fg;
                    _bgColor = bg;
                  }),
                ).animate().fadeIn(duration: 400.ms).scale(
                    begin: const Offset(0.9, 0.9), curve: Curves.easeOutBack),
              ],
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputFields() {
    switch (_selectedType) {
      case 'URL':
        return _Field(
          label: 'Website URL',
          hint: 'https://example.com',
          controller: _urlCtrl,
          icon: Icons.link_rounded,
          keyboardType: TextInputType.url,
          validator: (v) {
            final val = v?.trim() ?? '';
            if (val.isEmpty) return 'Please enter a URL';
            final full = _withScheme(val);
            final uri = Uri.tryParse(full);
            if (uri == null || !uri.hasAuthority || !uri.host.contains('.')) {
              return 'Please enter a valid URL (e.g. google.com)';
            }
            return null;
          },
        );

      case 'Text':
        return _Field(
          label: 'Text Content',
          hint: 'Enter any text...',
          controller: _textCtrl,
          icon: Icons.text_fields_rounded,
          maxLines: 4,
          validator: (v) =>
              v == null || v.trim().isEmpty ? 'Please enter some text' : null,
        );

      case 'Contact':
        return Column(children: [
          _Field(
            label: 'Full Name *',
            hint: 'John Doe',
            controller: _nameCtrl,
            icon: Icons.person_rounded,
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Name is required' : null,
          ),
          const SizedBox(height: 12),
          _Field(
            label: 'Phone Number',
            hint: '+8801XXXXXXXXX',
            controller: _phoneCtrl,
            icon: Icons.phone_rounded,
            keyboardType: TextInputType.phone,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return null;
              final clean = v.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
              if (!RegExp(r'^\d+$').hasMatch(clean)) {
                return 'Only numbers, +, -, (), spaces allowed';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          _Field(
            label: 'Email',
            hint: 'john@example.com',
            controller: _emailCtrl,
            icon: Icons.email_rounded,
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return null;
              if (!RegExp(r'^[\w\.\+\-]+@[\w\-]+\.[a-zA-Z]{2,}$')
                  .hasMatch(v.trim())) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
        ]);

      case 'WiFi':
        return Column(children: [
          _Field(
            label: 'Network Name (SSID)',
            hint: 'MyWiFi',
            controller: _ssidCtrl,
            icon: Icons.wifi_rounded,
            validator: (v) => v == null || v.trim().isEmpty
                ? 'Network name is required'
                : null,
          ),
          const SizedBox(height: 12),
          _Field(
            label: 'Password',
            hint: '••••••••',
            controller: _passCtrl,
            icon: Icons.lock_rounded,
            obscureText: true,
            validator: (v) {
              if (_wifiType == 'None') return null;
              final val = v ?? '';
              if (val.isEmpty) return 'Password is required for $_wifiType';
              if (_wifiType == 'WPA' && val.length < 8) {
                return 'WPA password must be at least 8 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          GlassContainer(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Security Type',
                  style: TextStyle(fontSize: 13, color: context.txtSecondary)),
              const SizedBox(height: 10),
              Row(
                children: ['WPA', 'WEP', 'None'].map((type) {
                  final selected = _wifiType == type;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _wifiType = type),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.success.withOpacity(0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: selected
                                ? AppColors.success.withOpacity(0.4)
                                : context.borderColor,
                            width: 0.5,
                          ),
                        ),
                        child: Text(type,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 12,
                                color: selected
                                    ? AppColors.success
                                    : context.txtMuted,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Switch(
                  value: _wifiHidden,
                  onChanged: (v) => setState(() => _wifiHidden = v),
                  activeColor: AppColors.success,
                  trackColor: WidgetStateProperty.all(context.bgHighlight),
                ),
                Text('Hidden network',
                    style:
                        TextStyle(fontSize: 13, color: context.txtSecondary)),
              ]),
            ]),
          ),
        ]);

      case 'Email':
        return _Field(
          label: 'Email Address',
          hint: 'example@email.com',
          controller: _emailCtrl,
          icon: Icons.email_rounded,
          keyboardType: TextInputType.emailAddress,
          validator: (v) {
            final val = v?.trim() ?? '';
            if (val.isEmpty) return 'Please enter an email address';
            if (!RegExp(r'^[\w\.\+\-]+@[\w\-]+\.[a-zA-Z]{2,}$').hasMatch(val)) {
              return 'Please enter a valid email (e.g. name@gmail.com)';
            }
            return null;
          },
        );

      case 'Phone':
        return _Field(
          label: 'Phone Number',
          hint: '+8801XXXXXXXXX',
          controller: _phoneCtrl,
          icon: Icons.phone_rounded,
          keyboardType: TextInputType.phone,
          validator: (v) {
            final val = v?.trim() ?? '';
            if (val.isEmpty) return 'Please enter a phone number';
            final clean = val.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
            if (!RegExp(r'^\d+$').hasMatch(clean)) {
              return 'Only numbers, +, -, (), spaces allowed';
            }
            return null;
          },
        );

      default:
        return const SizedBox();
    }
  }
}

class _Field extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final IconData icon;
  final TextInputType? keyboardType;
  final int? maxLines;
  final bool obscureText;
  final String? Function(String?)? validator;

  const _Field({
    required this.label,
    required this.hint,
    required this.controller,
    required this.icon,
    this.keyboardType,
    this.maxLines,
    this.obscureText = false,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 6),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                color: context.txtSecondary,
                fontWeight: FontWeight.w500)),
      ),
      TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines ?? 1,
        obscureText: obscureText,
        style: TextStyle(color: context.txtPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: context.txtMuted, size: 18),
        ),
        validator: validator,
      ),
    ]);
  }
}

class _QRPreview extends StatelessWidget {
  final String data;
  final Color fgColor;
  final Color bgColor;
  final GlobalKey previewKey;
  final VoidCallback onSave;
  final VoidCallback onShare;
  final bool isSaving;
  final void Function(Color fg, Color bg) onColorChange;

  const _QRPreview({
    required this.data,
    required this.fgColor,
    required this.bgColor,
    required this.previewKey,
    required this.onSave,
    required this.onShare,
    required this.isSaving,
    required this.onColorChange,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      borderColor: AppColors.primary.withOpacity(0.2),
      child: Column(children: [
        RepaintBoundary(
          key: previewKey,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: bgColor, borderRadius: BorderRadius.circular(16)),
            child: QrImageView(
              data: data,
              version: QrVersions.auto,
              size: 200,
              backgroundColor: bgColor,
              dataModuleStyle: QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: fgColor,
              ),
              eyeStyle: QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: fgColor,
              ),
              errorCorrectionLevel: QrErrorCorrectLevel.H,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          data.length > 60 ? '${data.substring(0, 60)}...' : data,
          style: TextStyle(fontSize: 11, color: context.txtMuted),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 16),
        Row(children: [
          Text('Style:',
              style: TextStyle(fontSize: 12, color: context.txtSecondary)),
          const SizedBox(width: 10),
          // সব style এ dark code + light background — উল্টো (light-on-dark)
          // QR অনেক scanner পড়তে পারে না
          ...[
            [AppColors.darkBgDeep, AppColors.surfaceWhite],
            [const Color(0xFF4527C9), Colors.white],
            [const Color(0xFFA3123F), Colors.white],
            [const Color(0xFF07694A), Colors.white],
          ].map((pair) {
            final fg = pair[0];
            final bg = pair[1];
            return GestureDetector(
              onTap: () => onColorChange(fg, bg),
              child: Container(
                width: 28,
                height: 28,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: context.borderColor, width: 0.5),
                ),
                child: Center(
                    child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                      color: fg, borderRadius: BorderRadius.circular(3)),
                )),
              ),
            );
          }),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
              child: ActionButton(
            label: 'Save',
            icon: Icons.download_rounded,
            onTap: onSave,
            isLoading: isSaving,
          )),
          const SizedBox(width: 10),
          Expanded(
              child: ActionButton(
            label: 'Share',
            icon: Icons.share_rounded,
            onTap: onShare,
            outlined: true,
          )),
        ]),
      ]),
    );
  }
}
