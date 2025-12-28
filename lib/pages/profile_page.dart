import 'package:attendance/pages/login_page.dart';
import 'package:attendance/theme/app_colors.dart';
import 'package:attendance/widgets/app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../logic/auth/auth_cubit.dart';
import '../logic/profile/profile_cubit.dart';
import '../models/company_profile.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String _username = "";
  final String _password = "********";

  // Company fields
  String _companyName = "-";
  String _companyCode = "-";
  String _companyAddress = "-";
  double? _lat;
  double? _lng;
  int? _radius;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // load dari cubit
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProfileCubit>().load();
    });
  }

  // util: format jam kerja seperti sebelumny

  Future<void> _showLogoutDialog() async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
            side: BorderSide(color: Colors.grey.shade300, width: 0.5),
          ),
          title: const Text(
            "Logout",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text("Apakah anda yakin akan logout?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Tidak", style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                await context.read<AuthCubit>().logout();
                if (!mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (route) => false,
                );
              },
              child: const Text("Logout", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openInMaps() async {
    final uri = Uri.parse('https://www.google.com/maps?q=$_lat,$_lng');
    final ok = await canLaunchUrl(uri);
    if (!ok) {}
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open Maps')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<AuthCubit, AuthState>(
          listenWhen: (p, c) => c is AuthLoggedOut || c is AuthFailure,
          listener: (context, state) {
            if (state is AuthFailure || state is AuthLoggedOut) {
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (route) => false,
                );
              }
            }
          },
        ),
        BlocListener<ProfileCubit, ProfileState>(
          listenWhen: (p, c) =>
              c is ProfileLoading || c is ProfileLoaded || c is ProfileFailure,
          listener: (context, state) {
            if (state is ProfileLoading || state is ProfileInitial) {
              setState(() => _loading = true);
            } else if (state is ProfileLoaded) {
              final CompanyProfile? cp = state.company;
              setState(() {
                _loading = false;
                _username = state.username;

                _companyName = cp?.name ?? '-';
                _companyCode = cp?.companyCode ?? '-';
                _companyAddress = cp?.address ?? '-';

                _lat = cp?.location.latitude;
                _lng = cp?.location.longitude;
                _radius = cp?.location.radius;
              });
            } else if (state is ProfileFailure) {
              setState(() => _loading = false);
            }
          },
        ),
      ],
      child: Scaffold(
        appBar: buildCustomAppBar(
          title: "Profil",
          centerTitle: true,
          action: IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: _showLogoutDialog,
            tooltip: 'Logout',
          ),
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // ===== Account Card =====
                    _SectionCard(
                      title: "Informasi Akun",
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Avatar kecil
                            Container(
                              margin: const EdgeInsets.only(right: 16),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.blue,
                                  width: 1.0,
                                ),
                              ),
                              child: const CircleAvatar(
                                radius: 28,
                                backgroundImage: AssetImage(
                                  "assets/images/logo-hureo.png",
                                ),
                              ),
                            ),
                            // Detail akun
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _InfoTile(
                                    icon: Icons.person,
                                    label: "Username",
                                    value: _username,
                                    trailing: IconButton(
                                      icon: const Icon(Icons.copy, size: 18),
                                      onPressed: () {
                                        Clipboard.setData(
                                          ClipboardData(text: _username),
                                        );
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text("Username copied"),
                                            duration: Duration(
                                              milliseconds: 800,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _InfoTile(
                                    icon: Icons.lock,
                                    label: "Password",
                                    value: _password,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // ===== Company Card =====
                    _SectionCard(
                      title: "Informasi Perusahaan",
                      accent: Colors.blue,
                      children: [
                        _InfoTile(
                          icon: Icons.apartment,
                          label: "Perusahaan",
                          value: _companyName,
                        ),
                        const SizedBox(height: 12),
                        _InfoTile(
                          icon: Icons.qr_code_2,
                          label: "Kode Perusahaan",
                          value: _companyCode,
                          trailing: IconButton(
                            icon: const Icon(Icons.copy, size: 18),
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(text: _companyCode),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Company code copied"),
                                  duration: Duration(milliseconds: 800),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        _InfoTile(
                          icon: Icons.location_on_outlined,
                          label: "Alamat Perusahaan",
                          value: _companyAddress,
                          maxLines: 2,
                        ),
                        const SizedBox(height: 12),
                        if (_radius != null || _lat != null) ...[
                          const SizedBox(height: 12),
                          _InfoTile(
                            icon: Icons.safety_divider,
                            label: "Koordinat Perusahaan",
                            value:
                                "${_radius ?? '-'} m • ${_lat?.toStringAsFixed(6) ?? '-'}, ${_lng?.toStringAsFixed(6) ?? '-'}",
                            trailing: (_lat != null && _lng != null)
                                ? TextButton.icon(
                                    onPressed: _openInMaps,
                                    icon: const Icon(
                                      Icons.map,
                                      size: 18,
                                      color: Colors.blue,
                                    ),
                                    label: const Text(
                                      "Buka di Maps",
                                      style: TextStyle(color: Colors.blue),
                                    ),
                                  )
                                : null,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

/* ================== Reusable UI widgets (tidak diubah) ================== */

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Color? accent;
  const _SectionCard({
    required this.title,
    required this.children,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
        side: BorderSide(color: (accent ?? Colors.blue).withOpacity(0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 6,
                  height: 20,
                  decoration: BoxDecoration(
                    color: accent ?? Colors.blue,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final int maxLines;
  final Widget? trailing;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.maxLines = 1,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.blue, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
