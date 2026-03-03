import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/theme_notifier.dart';

/// DeFi Apps & Tools: swap links (Jupiter, Raydium, Orca) and utility dapps.
class DefiToolsScreen extends StatelessWidget {
  const DefiToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeNotifier>(
      builder: (context, themeNotifier, _) {
        return Scaffold(
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: themeNotifier.theme.gradient,
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildAppBar(context),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Swap & Trade',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _DeFiLinkCard(
                            title: 'Jupiter',
                            description: 'Best rates for token swaps. Aggregates liquidity across Solana DEXes.',
                            link: 'https://jup.ag/?ref=z82aogd2s13d',
                            iconUrl: 'https://www.google.com/s2/favicons?domain=jup.ag&sz=128',
                            fallbackIcon: Icons.swap_horiz,
                          ),
                          const SizedBox(height: 12),
                          _DeFiLinkCard(
                            title: 'Raydium',
                            description: 'Swap SOL to USDC and trade on Solana\'s leading AMM.',
                            link: 'https://raydium.io/swap/?inputMint=sol&outputMint=EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v&referrer=4bjTEWMmcoYVZ86zn6Jb49ERi4FMfZU6wXCTimPhNBpt',
                            iconUrl: 'https://www.google.com/s2/favicons?domain=raydium.io&sz=128',
                            fallbackIcon: Icons.water_drop,
                          ),
                          const SizedBox(height: 12),
                          _DeFiLinkCard(
                            title: 'Orca',
                            description: 'User-friendly DEX with concentrated liquidity and low fees.',
                            link: 'https://www.orca.so/trade',
                            iconUrl: 'https://www.google.com/s2/favicons?domain=orca.so&sz=128',
                            fallbackIcon: Icons.pets,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Utilities',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _ClaimYourSolCard(),
                          const SizedBox(height: 12),
                          _SolIncineratorCard(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Text(
            'DeFi Apps&Tools',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Reusable card: icon, title, description, opens link in browser.
class _DeFiLinkCard extends StatelessWidget {
  final String title;
  final String description;
  final String link;
  final String iconUrl;
  final IconData fallbackIcon;

  const _DeFiLinkCard({
    required this.title,
    required this.description,
    required this.link,
    required this.iconUrl,
    required this.fallbackIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () async {
          try {
            await launchUrl(
              Uri.parse(link),
              mode: LaunchMode.externalApplication,
            );
          } catch (_) {}
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  iconUrl,
                  width: 56,
                  height: 56,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    width: 56,
                    height: 56,
                    color: Colors.white12,
                    child: Icon(fallbackIcon, color: Colors.white54, size: 28),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.open_in_new, size: 20, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }
}

/// Claim Your Sol — open in browser.
class _ClaimYourSolCard extends StatelessWidget {
  static const String _logoUrl = 'https://claimyoursol.com/images/cys-logo.png';
  static const String _linkUrl = 'https://claimyoursol.com/4ChFt9LThh66mPNGDjkk';

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () async {
          try {
            await launchUrl(
              Uri.parse(_linkUrl),
              mode: LaunchMode.externalApplication,
            );
          } catch (_) {}
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  _logoUrl,
                  width: 56,
                  height: 56,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    width: 56,
                    height: 56,
                    color: Colors.white12,
                    child: const Icon(Icons.account_balance_wallet, color: Colors.white54, size: 28),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Claim Your Sol back',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Claim your SOL from forgotten empty SPL accounts.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.open_in_new, size: 20, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sol Incinerator — open in browser.
class _SolIncineratorCard extends StatelessWidget {
  static const String _logoUrl = 'https://sol-incinerator.com/img/incinerator-logo.svg';
  static const String _linkUrl = 'https://sol-incinerator.com/?ref=rc0v95cn';

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () async {
          try {
            await launchUrl(
              Uri.parse(_linkUrl),
              mode: LaunchMode.externalApplication,
            );
          } catch (_) {}
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SvgPicture.network(
                    _logoUrl,
                    width: 56,
                    height: 56,
                    fit: BoxFit.contain,
                    placeholderBuilder: (context) => Container(
                      color: Colors.white12,
                      alignment: Alignment.center,
                      child: const Icon(Icons.local_fire_department, color: Colors.white54, size: 28),
                    ),
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.white12,
                      alignment: Alignment.center,
                      child: const Icon(Icons.local_fire_department, color: Colors.white54, size: 28),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sol Incinerator',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Claim SOL from vacant token accounts. Reclaim rent deposits, get your SOL refund, and burn unwanted NFTs and tokens.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.open_in_new, size: 20, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }
}

