import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/auth_controller.dart';
import '../../credit/screens/credit_screen.dart';
import '../../profile/screens/profile_screen.dart';

/// Accueil boutique : navigation à 4 onglets.
/// Profil = construit (lot 3). Commandes / Produits / Crédit = à venir.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _titles = ['Commandes', 'Produits', 'Crédit', 'Profil'];

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AuthController>().store;

    return Scaffold(
      appBar: AppBar(
        title: Text(_index == 3 ? 'Mon profil' : (store?.name ?? 'Mon magasin')),
      ),
      body: Column(
        children: [
          if (store != null && !store.isVerified)
            Container(
              width: double.infinity,
              color: AppColors.warningLight,
              padding: const EdgeInsets.all(12),
              child: const Text(
                '⏳ Votre magasin est en attente de vérification par VigiRoutes. '
                'Ajoutez vos documents dans l\'onglet Profil pour être validé.',
                style: TextStyle(fontSize: 13),
              ),
            ),
          Expanded(child: _body()),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined), label: 'Commandes'),
          NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined), label: 'Produits'),
          NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              label: 'Crédit'),
          NavigationDestination(
              icon: Icon(Icons.store_outlined), label: 'Profil'),
        ],
      ),
    );
  }

  Widget _body() {
    switch (_index) {
      case 2:
        return const CreditScreen();
      case 3:
        return const ProfileScreen();
      default:
        return Center(
          child: Text(
            '${_titles[_index]}\n(à construire au prochain lot)',
            textAlign: TextAlign.center,
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 16),
          ),
        );
    }
  }
}
