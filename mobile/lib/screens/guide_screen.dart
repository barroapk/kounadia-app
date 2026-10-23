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
        DocSection('Premium', Icons.workspace_premium_rounded, [
          'Premium débloque les Prédictions, Coup sûr, la création de coupons, les faits du jour et la forme des équipes.',
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
