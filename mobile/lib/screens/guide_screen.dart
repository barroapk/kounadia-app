import 'package:flutter/material.dart';
import '../services/user_prefs.dart';
import '../config/store.dart';
import '../widgets/doc_view.dart';

/// Guide d'utilisation de KOUNADIA.
class GuideScreen extends StatelessWidget {
  GuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bf = UserPrefs.iso == 'BF';
    return DocView(
      title: "Guide d'utilisation",
      intro: 'Tout ce qu\'il faut savoir pour profiter de KOUNADIA. Touche une rubrique pour l\'ouvrir.',
      footer: "18+ · Aucun pronostic n'est garanti · Jouez de manière responsable.",
      sections: [
        DocSection('Premiers pas', Icons.rocket_launch_rounded, [
          "À la première ouverture, KOUNADIA reconnaît ton pays : la langue, la monnaie et l'heure des matchs s'adaptent automatiquement.",
          '• Tu peux tout changer à tout moment dans Paramètres › Préférences.',
          "• Les heures des matchs sont toujours affichées à l'heure de ton téléphone.",
          '• Crée ton compte pour retrouver tes favoris et ton abonnement sur n\'importe quel téléphone.',
        ]),
        DocSection('Matchs et scores en direct', Icons.sports_soccer_rounded, [
          "L'onglet Matchs affiche les rencontres de football avec les scores mis à jour en direct.",
          '• La minute en rouge indique un match en cours.',
          '• Ajoute tes championnats favoris (Paramètres › Mes championnats) : ils apparaissent en premier.',
          '• Touche un match pour voir sa fiche : forme des équipes, statistiques et faits du jour.',
          '• Les classements de tous les championnats sont dans Paramètres › Classements.',
        ]),
        if (kV2) ...[
          DocSection('Coupon du jour', Icons.today_rounded, [
            "Chaque matin, KOUNADIA publie ses coupons du jour. Une fois publiés, ils ne changent plus.",
            '• Coupons gratuits : le Single du jour (un seul match, le plus sûr) et un coupon de 2 à 3 matchs, cote autour de 1,5.',
            '• Coupons VIP (Premium) : trois coupons à cote 2, 3 et 5.',
            "• Chaque pari a au moins une cote de 1,15. Un même match n'est jamais utilisé dans deux coupons.",
            '• Touche « Historique » sous un coupon pour voir ses résultats de cette semaine et de la semaine dernière.',
          ]),
          DocSection('Coups sûrs', Icons.verified_rounded, [
            "Les paris du jour les plus sûrs, sur d'autres matchs que ceux des coupons : un pari par match, de types variés.",
            "• Un pari n'entre dans les Coups sûrs que si KOUNADIA et PrimaTips sont d'accord. Si nos analystes Expert l'ont aussi choisi, c'est indiqué.",
            '• Touche ☰ pour choisir une catégorie : double chance, victoire, buts, les deux marquent, mi-temps, corners, fautes, tirs, tirs cadrés, coupons cote 2+, 5+ et 10+.',
            '• Une catégorie affiche les paris à 70 % de chance ou plus. Leur nombre change chaque jour selon les matchs.',
            '• Touche ☆ pour suivre un pari dans « Mes favoris ».',
            '• Touche un match pour voir « Pourquoi ce choix », avec les chiffres du match.',
            '• Pour les corners, fautes et tirs, la carte affiche le nombre de chaque équipe à la place du score.',
            "• ≈ devant une cote : cote estimée par KOUNADIA. Vérifie la cote chez ton bookmaker.",
          ]),
          DocSection('Les codes des paris', Icons.tag_rounded, [
            '• 1 : victoire de l\'équipe à domicile · 2 : victoire de l\'équipe à l\'extérieur · X : match nul.',
            '• 1X : domicile ou nul · X2 : extérieur ou nul · 12 : pas de match nul.',
            '• +2,5 : plus de 2,5 buts (3 buts ou plus) · -2,5 : moins de 2,5 buts (2 buts ou moins).',
          ]),
          DocSection('Statistiques des championnats', Icons.query_stats_rounded, [
            'Paramètres › Statistiques des championnats : moyennes de buts, corners, fautes et cartons des grands championnats européens, équipe par équipe.',
          ]),
          DocSection('Créer un coupon', Icons.confirmation_number_rounded, [
            "Choisis la cote que tu vises, le nombre de matchs et la période : KOUNADIA compose ton coupon à partir de ses analyses.",
            '• Partage ton coupon en image en un geste.',
            '• Le suivi est automatique : chaque match passe en gagné ou perdu.',
          ]),
        ] else ...[
          DocSection('Prédictions', Icons.insights_rounded, [
          "L'onglet Prédictions réunit trois sélections, mises à jour chaque jour :",
          '• Kounadia IA : le score prédit et le résultat le plus probable de chaque match.',
          '• Expert : les pronostics de nos analystes, avec leur indice de confiance.',
          '• Coup sûr : les sélections les plus fiables du jour, publiées chaque matin à 6h.',
          'Pendant un match, la carte affiche la minute et le score. À la fin, le statut apparaît : ✅ Gagné ou ❌ Perdu.',
          "Les pronostics de la veille restent visibles, avec leur résultat, jusqu'à l'arrivée des nouveaux.",
        ]),
          DocSection('Créer un coupon', Icons.confirmation_number_rounded, [
          "Choisis la cote que tu vises, le nombre de matchs et la période : KOUNADIA compose ton coupon à partir de ses analyses.",
          '• Partage ton coupon en image en un geste.',
          '• Le suivi est automatique : chaque match passe en gagné ou perdu.',
        ]),
          DocSection('Historique', Icons.history_rounded, [
          "L'onglet Historique montre les résultats des pronostics passés : d'hier en détail et le bilan de la semaine.",
        ]),
        ],
        DocSection('Premium', Icons.workspace_premium_rounded, [
          kV2 ? 'Premium débloque les coupons VIP, les Coups sûrs, la création de coupons, les faits du jour et la forme des équipes.' : 'Premium débloque les Prédictions, Coup sûr, la création de coupons, les faits du jour et la forme des équipes.',
          '• Offres : 3 jours, hebdomadaire, mensuel ou annuel (Paramètres › Mon compte).',
          '• Paiement sécurisé par Mobile Money.',
          "• L'activation est automatique dès que le paiement est validé.",
          "• Les jours achetés s'ajoutent à ton abonnement en cours : tu ne perds rien.",
          '• Sans engagement : rien ne se renouvelle tout seul.',
        ]),
        DocSection('Mon compte', Icons.person_rounded, [
          '• Inscription avec un nom d\'utilisateur, ton adresse e-mail et un mot de passe.',
          '• Ton téléphone peut enregistrer l\'e-mail et le mot de passe pour te connecter plus vite.',
          '• Mot de passe oublié : touche « Mot de passe oublié ? », entre ton e-mail et saisis le code à 6 chiffres reçu (valable 30 minutes).',
          '• Tu restes connecté tant que tu utilises l\'application.',
          '• Ne partage jamais ton mot de passe ni ton code.',
        ]),
        if (bf && !kPlay)
          DocSection('Dépôt · Retrait 1xBet', Icons.swap_vert_rounded, [
            'Recharge ou retire ton compte 1xBet avec KOUNADIA SERVICE, rapidement et en toute confiance.',
            '• Touche le bouton « Dépôt · Retrait » en bas de l\'écran.',
            '• Choisis Dépôt ou Retrait et suis les étapes.',
            '• Un agent traite ta demande sur WhatsApp.',
            '• Code promo 1xBet : 99KND.',
          ]),
        DocSection("Besoin d'aide ?", Icons.support_agent_rounded, [
          'Paramètres › Contacter le support : écris-nous par WhatsApp ou par e-mail, nous répondons rapidement.',
        ]),
      ],
    );
  }
}
