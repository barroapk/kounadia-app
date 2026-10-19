import 'package:flutter/material.dart';
import '../widgets/doc_view.dart';

const _contact = 'pierreclavers56@gmail.com';
const _maj = 'Dernière mise à jour : octobre 2026';

/// Conditions d'utilisation.
class TermsScreen extends StatelessWidget {
  TermsScreen({super.key});

  @override
  Widget build(BuildContext context) => DocView(
        title: "Conditions d'utilisation",
        intro: "En utilisant KOUNADIA, tu acceptes les conditions ci-dessous. Merci de les lire attentivement.",
        footer: 'KOUNADIA SERVICE · Burkina Faso\n$_maj',
        openAll: true,
        sections: [
          DocSection('1. Le service', Icons.apps_rounded, [
            "KOUNADIA est une application d'informations sur le football : scores en direct, classements, statistiques et pronostics. Elle est éditée par KOUNADIA SERVICE (Burkina Faso).",
          ]),
          DocSection('2. Âge minimum', Icons.badge_rounded, [
            "Les contenus liés aux paris sont réservés aux personnes de 18 ans et plus. En utilisant ces contenus, tu confirmes avoir l'âge légal dans ton pays.",
          ]),
          DocSection('3. Pronostics', Icons.insights_rounded, [
            "Les pronostics sont fournis à titre d'information uniquement. Ils ne constituent ni une garantie de résultat, ni un conseil financier.",
            "Toute décision de pari relève de ta seule responsabilité. KOUNADIA SERVICE ne peut être tenu responsable d'une perte.",
          ]),
          DocSection('4. Compte', Icons.person_rounded, [
            '• Un compte est personnel : garde ton mot de passe secret.',
            '• Les informations fournies (nom d\'utilisateur, e-mail) doivent être exactes.',
            "• En cas d'utilisation frauduleuse ou abusive, le compte peut être suspendu.",
          ]),
          DocSection('5. Abonnement Premium', Icons.workspace_premium_rounded, [
            "• Premium est payé à l'avance, pour la durée choisie, sans renouvellement automatique.",
            '• Il est activé dès la validation du paiement.',
            "• Un paiement validé n'est pas remboursable, sauf erreur technique de notre part : contacte le support.",
            '• Le contenu Premium peut évoluer pour améliorer le service.',
          ]),
          DocSection('6. Utilisation correcte', Icons.gpp_good_rounded, [
            "Il est interdit de copier, revendre ou diffuser à grande échelle les contenus de l'application, ou de tenter d'en perturber le fonctionnement.",
          ]),
          DocSection('7. Disponibilité', Icons.cloud_done_rounded, [
            "Nous faisons de notre mieux pour que le service soit disponible en permanence, sans pouvoir le garantir. Les scores et résultats peuvent parfois comporter un léger retard ou une erreur.",
          ]),
          DocSection('8. Modifications et contact', Icons.mail_rounded, [
            "Ces conditions peuvent être mises à jour ; la version en vigueur est toujours disponible dans l'application.",
            'Contact : $_contact',
          ]),
        ],
      );
}

/// Politique de confidentialité.
class PrivacyScreen extends StatelessWidget {
  PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) => DocView(
        title: 'Confidentialité',
        intro: 'Ta vie privée compte. Voici quelles données nous utilisons, pourquoi, et tes droits.',
        footer: 'KOUNADIA SERVICE · Burkina Faso\n$_maj',
        openAll: true,
        sections: [
          DocSection('Données que nous conservons', Icons.folder_shared_rounded, [
            "• Ton compte : nom d'utilisateur, adresse e-mail et mot de passe chiffré (personne, pas même nous, ne peut le lire).",
            '• Tes préférences : pays, langue, devise, championnats et équipes favoris.',
            '• Tes abonnements : offre choisie, montant et date de paiement.',
            "• Des statistiques d'utilisation anonymes (écrans consultés) pour améliorer l'application.",
          ]),
          DocSection('Ce que nous ne faisons pas', Icons.block_rounded, [
            '• Nous ne vendons jamais tes données.',
            '• Pour ton compte, nous ne demandons ni numéro de téléphone, ni pièce d\'identité.',
            "• Tes informations de paiement Mobile Money sont saisies chez notre partenaire de paiement, jamais dans l'application.",
          ]),
          DocSection('Pourquoi ces données', Icons.lightbulb_rounded, [
            '• Faire fonctionner ton compte et ton abonnement.',
            '• Te permettre de retrouver tes préférences sur un autre téléphone.',
            '• T\'envoyer un code par e-mail si tu oublies ton mot de passe.',
            "• Améliorer l'application.",
          ]),
          DocSection('Sécurité et conservation', Icons.lock_rounded, [
            "Les échanges avec nos serveurs sont chiffrés. Les données sont conservées tant que ton compte existe ; les traces techniques sont supprimées automatiquement après quelques jours.",
          ]),
          DocSection('Tes droits', Icons.verified_user_rounded, [
            'Tu peux demander à consulter, corriger ou supprimer ton compte et tes données à tout moment.',
            'Écris-nous : $_contact (depuis l\'adresse e-mail de ton compte).',
          ]),
        ],
      );
}

/// Jeu responsable.
class ResponsibleScreen extends StatelessWidget {
  ResponsibleScreen({super.key});

  @override
  Widget build(BuildContext context) => DocView(
        title: 'Jeu responsable',
        intro: 'Le pari doit rester un loisir. Quelques règles simples pour garder le contrôle.',
        footer: '18+ · Jouez de manière responsable.',
        openAll: true,
        sections: [
          DocSection('Les bons réflexes', Icons.health_and_safety_rounded, [
            '• Les paris sont réservés aux personnes de 18 ans et plus.',
            '• Fixe-toi un budget et ne le dépasse jamais.',
            '• Ne mise que ce que tu peux te permettre de perdre.',
            '• Ne cherche pas à « te refaire » après une perte.',
            "• Aucun pronostic n'est garanti, même avec une forte probabilité.",
            "• Ne parie pas sous le coup de l'émotion, de la fatigue ou de l'alcool.",
          ]),
          DocSection('Les signaux d\'alerte', Icons.warning_amber_rounded, [
            '• Tu mises plus que prévu ou plus souvent.',
            '• Tu empruntes de l\'argent pour parier.',
            '• Le jeu prend la place de ta famille, de ton travail ou de tes études.',
            'Si tu te reconnais, fais une pause et parles-en à un proche ou à un professionnel de santé.',
          ]),
        ],
      );
}
