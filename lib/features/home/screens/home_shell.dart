import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/auth_controller.dart';

/// Accueil boutique — SQUELETTE (lot 1) : navigation à 4 onglets.
/// Le contenu réel (commandes, produits, crédit, profil) viendra aux lots suivants.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final store = auth.store;

    final tabs = ['Commandes', 'Produits', 'Crédit', 'Profil'];

    return Scaffold(
      appBar: AppBar(
        title: Text(store?.name ?? 'Mon magasin'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthController>().logout(),
          ),
        ],
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
                'Vous pourrez recevoir des commandes une fois validé.',
                style: TextStyle(fontSize: 13),
              ),
            ),
          Expanded(
            child: Center(
              child: Text(
                '${tabs[_index]}\n(à construire)',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 16),
              ),
            ),
          ),
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
}
