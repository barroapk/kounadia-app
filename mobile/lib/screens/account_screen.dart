import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/account.dart';
import '../services/analytics.dart';
import '../services/currency.dart';
import '../services/user_prefs.dart';
import '../widgets/forecast_card.dart' show K, two;

String fcfa(int v) => '${v.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ' ')} F';
String _date(DateTime d) => '${two(d.day)}/${two(d.month)}/${d.year} à ${two(d.hour)}h${two(d.minute)}';

/// Mon compte : connexion / inscription par e-mail, profil, offres Premium et paiement.
class AccountScreen extends StatefulWidget {
  final bool signup;
  AccountScreen({super.key, this.signup = false});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  late bool _signup = widget.signup;
  bool _busy = false;
  bool _tried = false;
  bool _showPw = false;
  String? _err;
  final _name = TextEditingController();
  final _mail = TextEditingController();
  final _pw = TextEditingController();
  final _pw2 = TextEditingController();

  @override
  void initState() {
    super.initState();
    Account.refresh();
    Account.warmUp();
    Analytics.log('account_open');
    for (final c in [_name, _mail, _pw, _pw2]) {
      c.addListener(() {
        if (_tried && mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _mail, _pw, _pw2]) {
      c.dispose();
    }
    super.dispose();
  }

  // Vérifications affichées sous chaque champ (après le premier essai).
  String? get _nameErr => !_signup || _name.text.trim().length >= 2 ? null : '2 caractères minimum';
  String? get _mailErr => isEmail(_mail.text) || (!_signup && RegExp(r'^\+?\d{8,15}$').hasMatch(_mail.text.trim())) ? null : (_mail.text.trim().isEmpty ? 'Entre ton adresse e-mail' : 'Adresse e-mail invalide (ex. : nom@gmail.com)');
  String? get _pwErr => _pw.text.length >= 6 ? null : '6 caractères minimum';
  String? get _pw2Err => !_signup || _pw2.text == _pw.text ? null : 'Les deux mots de passe ne sont pas identiques';

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _tried = true;
      _err = null;
    });
    if (_nameErr != null || _mailErr != null || _pwErr != null || _pw2Err != null) return;
    setState(() => _busy = true);
    try {
      if (_signup) {
        await Account.register(_name.text.trim(), _mail.text, _pw.text, _pw2.text);
        Analytics.log('account_register');
      } else {
        await Account.login(_mail.text, _pw.text);
      }
      // Propose au gestionnaire de mots de passe (Google) d'enregistrer l'e-mail et le mot de passe.
      TextInput.finishAutofillContext(shouldSave: true);
    } catch (e) {
      _err = e.toString();
    }
    if (mounted) setState(() => _busy = false);
  }

  Widget _input(TextEditingController c, String label, IconData icon,
          {bool pw = false, String? error, Iterable<String>? hints, TextInputType? type, TextInputAction? action, VoidCallback? onDone}) =>
      Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          obscureText: pw && !_showPw,
          enableSuggestions: !pw,
          autocorrect: false,
          keyboardType: type,
          textInputAction: action ?? TextInputAction.next,
          autofillHints: hints,
          onSubmitted: onDone == null ? null : (_) => onDone(),
          style: TextStyle(color: K.text),
          decoration: _dec(label, icon).copyWith(
            errorText: _tried ? error : null,
            suffixIcon: pw
                ? IconButton(
                    icon: Icon(_showPw ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: K.muted),
                    onPressed: () => setState(() => _showPw = !_showPw),
                  )
                : null,
          ),
        ),
      );

  Widget _auth() {
    return AutofillGroup(
      child: ListView(padding: EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
        Container(
          padding: EdgeInsets.all(3),
          decoration: BoxDecoration(color: K.card, borderRadius: BorderRadius.circular(13), border: Border.all(color: K.border)),
          child: Row(children: [
            for (final (v, l) in [(false, 'Se connecter'), (true, 'Créer un compte')])
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _signup = v;
                    _err = null;
                    _tried = false;
                  }),
                  child: Container(
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: _signup == v ? K.indigo : Colors.transparent, borderRadius: BorderRadius.circular(10)),
                    child: Text(l, style: TextStyle(color: _signup == v ? Colors.white : K.muted, fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
          ]),
        ),
        SizedBox(height: 18),
        if (_signup)
          _input(_name, "Nom d'utilisateur", Icons.person_rounded, error: _nameErr, hints: [AutofillHints.nickname]),
        _input(_mail, 'Adresse e-mail', Icons.alternate_email_rounded,
            error: _mailErr, type: TextInputType.emailAddress, hints: [AutofillHints.email, AutofillHints.username]),
        _input(_pw, _signup ? 'Mot de passe (6 caractères min.)' : 'Mot de passe', Icons.lock_rounded,
            pw: true,
            error: _pwErr,
            hints: [_signup ? AutofillHints.newPassword : AutofillHints.password],
            action: _signup ? TextInputAction.next : TextInputAction.done,
            onDone: _signup ? null : _submit),
        if (_signup)
          _input(_pw2, 'Confirmer le mot de passe', Icons.lock_outline_rounded,
              pw: true, error: _pw2Err, hints: [AutofillHints.newPassword], action: TextInputAction.done, onDone: _submit),
        if (_err != null)
          Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text(_err!, style: TextStyle(color: K.red, fontWeight: FontWeight.w700)),
          ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: K.indigo, minimumSize: Size.fromHeight(50)),
          onPressed: _busy ? null : _submit,
          child: _busy
              ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
              : Text(_signup ? 'Créer mon compte' : 'Me connecter', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ),
        if (!_signup)
          Center(
            child: TextButton(
              onPressed: _forgot,
              child: Text('Mot de passe oublié ?', style: TextStyle(color: K.indigoText, fontWeight: FontWeight.w700)),
            ),
          ),
      ]),
    );
  }

  Widget _sheetField(TextEditingController c, String label, IconData icon, {bool pw = false, TextInputType? type, Iterable<String>? hints}) => Padding(
        padding: EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: c,
          obscureText: pw,
          autocorrect: false,
          keyboardType: type,
          autofillHints: hints,
          style: TextStyle(color: K.text),
          decoration: _dec(label, icon),
        ),
      );

  /// Fenêtre en bas d'écran avec titre, champs et bouton (gère l'attente et les erreurs).
  Future<void> _sheet({
    required String title,
    String? intro,
    required List<Widget> Function(void Function(VoidCallback) set) fields,
    required String action,
    required Future<void> Function(void Function(VoidCallback) set) run,
  }) {
    String? err;
    var busy = false;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: K.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            child: AutofillGroup(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(title, style: TextStyle(color: K.text, fontSize: 19, fontWeight: FontWeight.w900)),
                if (intro != null) ...[
                  SizedBox(height: 6),
                  Text(intro, style: TextStyle(color: K.muted, fontSize: 13, height: 1.4)),
                ],
                SizedBox(height: 14),
                ...fields(set),
                if (err != null)
                  Padding(padding: EdgeInsets.only(bottom: 8), child: Text(err!, style: TextStyle(color: K.red, fontWeight: FontWeight.w700))),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: K.indigo, minimumSize: Size.fromHeight(50)),
                  onPressed: busy
                      ? null
                      : () async {
                          set(() {
                            busy = true;
                            err = null;
                          });
                          try {
                            await run(set);
                          } catch (e) {
                            err = e.toString();
                          }
                          if (ctx.mounted) set(() => busy = false);
                        },
                  child: busy
                      ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : Text(action, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  /// Mot de passe oublié : un code est envoyé à l'e-mail du compte.
  Future<void> _forgot() async {
    final mail = TextEditingController(text: _mail.text.trim());
    final code = TextEditingController(), a = TextEditingController(), b = TextEditingController();
    var sent = false;
    await _sheet(
      title: 'Mot de passe oublié',
      intro: 'Entre l\'e-mail de ton compte : tu vas recevoir un code à 6 chiffres.',
      fields: (set) => [
        _sheetField(mail, 'Adresse e-mail', Icons.alternate_email_rounded, type: TextInputType.emailAddress, hints: [AutofillHints.email]),
        if (sent) ...[
          Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text('Code envoyé ✅ Regarde ta boîte de réception (et les spams).',
                style: TextStyle(color: K.green, fontSize: 12.5, fontWeight: FontWeight.w700)),
          ),
          _sheetField(code, 'Code reçu (6 chiffres)', Icons.pin_rounded, type: TextInputType.number, hints: [AutofillHints.oneTimeCode]),
          _sheetField(a, 'Nouveau mot de passe (6 caractères min.)', Icons.lock_rounded, pw: true, hints: [AutofillHints.newPassword]),
          _sheetField(b, 'Confirmer le nouveau mot de passe', Icons.lock_outline_rounded, pw: true, hints: [AutofillHints.newPassword]),
        ],
      ],
      action: 'Valider',
      run: (set) async {
        if (!isEmail(mail.text)) throw 'Adresse e-mail invalide';
        if (!sent) {
          await Account.forgot(mail.text);
          set(() => sent = true);
          return;
        }
        if (code.text.trim().length != 6) throw 'Entre le code à 6 chiffres reçu par e-mail';
        if (a.text.length < 6) throw 'Mot de passe : 6 caractères minimum';
        if (a.text != b.text) throw 'Les deux mots de passe ne sont pas identiques';
        await Account.resetPassword(mail.text, code.text.trim(), a.text, b.text);
        TextInput.finishAutofillContext(shouldSave: true);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Mot de passe changé, tu es connecté ✅')));
        }
      },
    );
  }

  /// Changer son mot de passe (profil).
  Future<void> _changePw() async {
    final old = TextEditingController(), a = TextEditingController(), b = TextEditingController();
    await _sheet(
      title: 'Changer mon mot de passe',
      fields: (_) => [
        _sheetField(old, 'Mot de passe actuel', Icons.lock_rounded, pw: true, hints: [AutofillHints.password]),
        _sheetField(a, 'Nouveau mot de passe (6 caractères min.)', Icons.lock_rounded, pw: true, hints: [AutofillHints.newPassword]),
        _sheetField(b, 'Confirmer le nouveau mot de passe', Icons.lock_outline_rounded, pw: true, hints: [AutofillHints.newPassword]),
      ],
      action: 'Enregistrer',
      run: (_) async {
        if (a.text.length < 6) throw 'Mot de passe : 6 caractères minimum';
        if (a.text != b.text) throw 'Les deux mots de passe ne sont pas identiques';
        await Account.changePassword(old.text, a.text, b.text);
        TextInput.finishAutofillContext(shouldSave: true);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Mot de passe modifié ✅')));
        }
      },
    );
  }

  /// Ajouter / modifier l'e-mail du compte.
  Future<void> _editEmail() async {
    final c = TextEditingController(text: Account.user.value?.email ?? '');
    await _sheet(
      title: 'Mon adresse e-mail',
      intro: 'Elle sert à te connecter et à récupérer ton compte.',
      fields: (_) => [_sheetField(c, 'Adresse e-mail', Icons.alternate_email_rounded, type: TextInputType.emailAddress, hints: [AutofillHints.email])],
      action: 'Enregistrer',
      run: (_) async {
        if (!isEmail(c.text)) throw 'Adresse e-mail invalide';
        await Account.setEmail(c.text);
        if (mounted) Navigator.pop(context);
      },
    );
  }

  Future<void> _buy(KPlan p) async {
    setState(() => _busy = true);
    var waiting = true;
    void close() {
      if (waiting && mounted) {
        waiting = false;
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(canPop: false, child: _Connecting(plan: p)),
    );
    try {
      final (token, url) = await Account.startPayment(p.id);
      close();
      Analytics.log('pay_start', {'plan': p.id});
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (mounted) await showModalBottomSheet<void>(
            context: context,
            isDismissible: false,
            backgroundColor: K.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
            builder: (_) => _PayWait(token: token, plan: p),
          );
    } catch (e) {
      close();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
    if (mounted) setState(() => _busy = false);
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: K.muted),
        prefixIcon: Icon(icon, color: K.muted),
        filled: true,
        fillColor: K.card,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: K.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: K.border)),
      );

  Widget _profile(KUser u) {
    final on = u.premium;
    return RefreshIndicator(
      color: K.indigo,
      onRefresh: Account.refresh,
      child: ListView(padding: EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: on ? [Color(0xFF8A6A12), Color(0xFFD4A017)] : [Color(0xFF4F46E5), Color(0xFF7C3AED)]),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: Color(0x33FFFFFF),
              child: Text(u.username.isEmpty ? '?' : u.username[0].toUpperCase(),
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(u.username, style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
                if (u.email != null) Text(u.email!, style: TextStyle(color: Color(0xDDFFFFFF), fontSize: 13)),
                SizedBox(height: 6),
                Text(on ? '👑 Premium actif jusqu\'au ${_date(u.premiumUntil!)}' : 'Aucun abonnement actif',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
              ]),
            ),
          ]),
        ),
        if (u.email == null) ...[
          SizedBox(height: 12),
          Material(
            color: K.amber.withAlpha(30),
            borderRadius: BorderRadius.circular(14),
            child: ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: K.amber)),
              leading: Icon(Icons.shield_rounded, color: K.amber),
              title: Text('Ajoute ton adresse e-mail', style: TextStyle(color: K.text, fontWeight: FontWeight.w800)),
              subtitle: Text('Pour te connecter et récupérer ton compte facilement.', style: TextStyle(color: K.muted, fontSize: 12)),
              trailing: Icon(Icons.chevron_right_rounded, color: K.muted),
              onTap: _editEmail,
            ),
          ),
        ],
        SizedBox(height: 10),
        Row(children: [
          Icon(Icons.cloud_done_rounded, color: K.green, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text('Favoris, coupons et réglages sauvegardés dans ton compte.',
                style: TextStyle(color: K.muted, fontSize: 12.5)),
          ),
        ]),
        SizedBox(height: 18),
        Text(on ? 'Prolonger mon abonnement' : 'Choisir mon abonnement',
            style: TextStyle(color: K.text, fontSize: 16, fontWeight: FontWeight.w800)),
        SizedBox(height: 4),
        Text('Paiement sécurisé par Mobile Money. Les jours s\'ajoutent à ton abonnement en cours.',
            style: TextStyle(color: K.muted, fontSize: 12.5)),
        SizedBox(height: 12),
        for (final p in kPlans) _planTile(p),
        SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: _editEmail,
          icon: Icon(Icons.alternate_email_rounded, color: K.text),
          label: Text('Modifier mon e-mail', style: TextStyle(color: K.text)),
        ),
        SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _changePw,
          icon: Icon(Icons.lock_reset_rounded, color: K.text),
          label: Text('Changer mon mot de passe', style: TextStyle(color: K.text)),
        ),
        SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => Account.logout(),
          icon: Icon(Icons.logout_rounded, color: K.muted),
          label: Text('Se déconnecter', style: TextStyle(color: K.muted)),
        ),
      ]),
    );
  }

  Widget _planTile(KPlan p) {
    final best = p.id == 'month';
    final sub = switch (p.id) {
      'day' => '3 jours d\'accès complet · idéal pour essayer',
      'week' => '7 jours · soit 71 F par jour',
      'month' => '30 jours · le plus choisi',
      _ => '365 jours · 2 mois offerts',
    };
    return Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: Material(
        color: K.card,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _busy ? null : () => _buy(p),
          child: Container(
            padding: EdgeInsets.all(14),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14), border: Border.all(color: best ? K.amber : K.border, width: best ? 2 : 1)),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(p.label, style: TextStyle(color: K.text, fontSize: 15.5, fontWeight: FontWeight.w800)),
                    if (best) ...[
                      SizedBox(width: 8),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(color: K.amber, borderRadius: BorderRadius.circular(8)),
                        child: Text('POPULAIRE', style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w900)),
                      ),
                    ],
                  ]),
                  SizedBox(height: 2),
                  Text(sub, style: TextStyle(color: K.muted, fontSize: 12.5)),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(fcfa(p.price), style: TextStyle(color: K.indigoText, fontSize: 18, fontWeight: FontWeight.w900)),
                if (Fx.approx(p.price) != null)
                  Text(Fx.approx(p.price)!, style: TextStyle(color: K.muted, fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: K.bg,
      appBar: AppBar(
          backgroundColor: K.bg,
          foregroundColor: K.text,
          title: Text('Mon compte', style: TextStyle(fontWeight: FontWeight.w800))),
      body: ValueListenableBuilder<KUser?>(
        valueListenable: Account.user,
        builder: (_, u, __) => ValueListenableBuilder<int>(
          valueListenable: UserPrefs.changed,
          builder: (_, __, ___) => u == null ? _auth() : _profile(u),
        ),
      ),
    );
  }
}

/// Attente du paiement : vérification automatique toutes les 5 s.
class _PayWait extends StatefulWidget {
  final String token;
  final KPlan plan;
  _PayWait({required this.token, required this.plan});

  @override
  State<_PayWait> createState() => _PayWaitState();
}

class _PayWaitState extends State<_PayWait> with WidgetsBindingObserver {
  Timer? _t;
  String _st = 'pending';
  int _n = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _t = Timer.periodic(Duration(seconds: 5), (_) => _check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _t?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    if (_st == 'paid' || ++_n > 150) {
      _t?.cancel();
      return;
    }
    try {
      final st = await Account.paymentStatus(widget.token);
      if (!mounted) return;
      setState(() => _st = st);
      if (st == 'paid') {
        _t?.cancel();
        Analytics.log('pay_success', {'plan': widget.plan.id});
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final paid = _st == 'paid';
    final failed = _st == 'failure' || _st == 'no paid' || _st == 'error';
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (paid)
            Icon(Icons.verified_rounded, color: K.green, size: 56)
          else if (failed)
            Icon(Icons.error_rounded, color: K.red, size: 56)
          else
            SizedBox(width: 44, height: 44, child: CircularProgressIndicator(color: K.indigo)),
          SizedBox(height: 14),
          Text(
            paid ? 'Premium activé 🎉' : failed ? 'Paiement non abouti' : 'En attente du paiement…',
            style: TextStyle(color: K.text, fontSize: 19, fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 6),
          Text(
            paid
                ? 'Merci ! Tous les contenus KOUNADIA sont débloqués.'
                : failed
                    ? 'Aucun montant validé. Tu peux réessayer.'
                    : 'Valide le paiement ${widget.plan.label} (${fcfa(widget.plan.price)}) sur ton téléphone, puis reviens ici.',
            textAlign: TextAlign.center,
            style: TextStyle(color: K.muted, fontSize: 13.5, height: 1.4),
          ),
          SizedBox(height: 18),
          if (!paid && !failed)
            OutlinedButton(onPressed: _check, child: Text("J'ai payé, vérifier maintenant")),
          SizedBox(height: 6),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: K.indigo, minimumSize: Size.fromHeight(46)),
            onPressed: () => Navigator.pop(context),
            child: Text(paid ? 'Continuer' : 'Fermer'),
          ),
        ]),
      ),
    );
  }
}

/// Pendant la préparation du paiement.
class _Connecting extends StatefulWidget {
  final KPlan plan;
  _Connecting({required this.plan});

  @override
  State<_Connecting> createState() => _ConnectingState();
}

class _ConnectingState extends State<_Connecting> {
  Timer? _t;
  int _s = 0;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(Duration(seconds: 1), (_) {
      if (mounted) setState(() => _s++);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final msg = _s < 8 ? 'Patiente un instant…' : 'Préparation de ton paiement sécurisé…';
    return Dialog(
      backgroundColor: K.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(22, 26, 22, 22),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: 46, height: 46, child: CircularProgressIndicator(color: K.indigo, strokeWidth: 3.5)),
          SizedBox(height: 18),
          Text('Paiement en cours',
              textAlign: TextAlign.center, style: TextStyle(color: K.text, fontSize: 18, fontWeight: FontWeight.w900)),
          SizedBox(height: 6),
          Text('${widget.plan.label} · ${fcfa(widget.plan.price)}',
              textAlign: TextAlign.center, style: TextStyle(color: K.indigoText, fontSize: 14, fontWeight: FontWeight.w800)),
          SizedBox(height: 12),
          AnimatedSwitcher(
            duration: Duration(milliseconds: 300),
            child: Text(msg,
                key: ValueKey(msg),
                textAlign: TextAlign.center,
                style: TextStyle(color: K.muted, fontSize: 13.5, height: 1.4)),
          ),
          SizedBox(height: 14),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.lock_rounded, color: K.green, size: 15),
            SizedBox(width: 6),
            Text('Paiement sécurisé', style: TextStyle(color: K.muted, fontSize: 12)),
          ]),
        ]),
      ),
    );
  }
}
