import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/account.dart';
import '../services/analytics.dart';
import '../services/currency.dart';
import '../services/user_prefs.dart';
import '../config/countries.dart';
import '../widgets/region_pickers.dart';
import '../widgets/forecast_card.dart' show K, two;

String fcfa(int v) => '${v.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ' ')} F';
String _date(DateTime d) => '${two(d.day)}/${two(d.month)}/${d.year} à ${two(d.hour)}h${two(d.minute)}';

/// Mon compte : connexion / inscription, profil, offres Premium et paiement.
class AccountScreen extends StatefulWidget {
  final bool signup;
  AccountScreen({super.key, this.signup = false});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  late bool _signup = widget.signup;
  bool _busy = false;
  String? _err;
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _pw = TextEditingController();
  final _pw2 = TextEditingController();
  KCountry _country = UserPrefs.country ?? countryByIso('BF')!;
  String get _cc => _country.dial;

  /// Numéro complet : « +… » ou « 00… » tel quel, sinon indicatif choisi + numéro.
  String _fullPhone() {
    final t = _phone.text.trim();
    final d = t.replaceAll(RegExp(r'\D'), '');
    if (t.startsWith('+')) return d;
    if (d.startsWith('00')) return d.substring(2);
    return '$_cc$d';
  }

  @override
  void initState() {
    super.initState();
    Account.refresh();
    Account.warmUp();
    Analytics.log('account_open');
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _pw, _pw2]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      if (_signup) {
        await Account.register(_name.text.trim(), _fullPhone(), _pw.text, _pw2.text);
        Analytics.log('account_register');
      } else {
        await Account.login(_fullPhone(), _pw.text);
      }
    } catch (e) {
      _err = e.toString();
    }
    if (mounted) setState(() => _busy = false);
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

  Widget _field(TextEditingController c, String label, IconData icon, {bool pw = false, bool phone = false}) => Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          obscureText: pw,
          keyboardType: phone ? TextInputType.phone : TextInputType.text,
          style: TextStyle(color: K.text),
          decoration: _dec(label, icon),
        ),
      );

  Widget _auth() {
    return ListView(padding: EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
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
                }),
                child: Container(
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: _signup == v ? K.indigo : Colors.transparent, borderRadius: BorderRadius.circular(10)),
                  child: Text(l,
                      style: TextStyle(color: _signup == v ? Colors.white : K.muted, fontWeight: FontWeight.w800)),
                ),
              ),
            ),
        ]),
      ),
      SizedBox(height: 18),
      if (_signup) _field(_name, "Nom d'utilisateur", Icons.person_rounded),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          height: 58,
          margin: EdgeInsets.only(right: 8),
          padding: EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(color: K.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: K.border)),
          child: InkWell(
            onTap: () async {
              final c = await pickCountry(context, dial: true, selected: _country.iso);
              if (c != null) setState(() => _country = c);
            },
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('${_country.flag} +${_country.dial}', style: TextStyle(color: K.text, fontSize: 15)),
              Icon(Icons.arrow_drop_down_rounded, color: K.muted),
            ]),
          ),
        ),
        Expanded(child: _field(_phone, 'Numéro de téléphone', Icons.phone_rounded, phone: true)),
      ]),
      _field(_pw, 'Mot de passe (6 caractères min.)', Icons.lock_rounded, pw: true),
      if (_signup) _field(_pw2, 'Confirmer le mot de passe', Icons.lock_outline_rounded, pw: true),
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
      SizedBox(height: 10),
      Text('La première connexion peut prendre jusqu\'à une minute.',
          textAlign: TextAlign.center, style: TextStyle(color: K.muted, fontSize: 12)),
    ]);
  }

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
                Text('+${u.phone}', style: TextStyle(color: Color(0xDDFFFFFF), fontSize: 13)),
                SizedBox(height: 6),
                Text(on ? '👑 Premium actif jusqu\'au ${_date(u.premiumUntil!)}' : 'Aucun abonnement actif',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
              ]),
            ),
          ]),
        ),
        SizedBox(height: 18),
        Text(on ? 'Prolonger mon abonnement' : 'Choisir mon abonnement',
            style: TextStyle(color: K.text, fontSize: 16, fontWeight: FontWeight.w800)),
        SizedBox(height: 4),
        Text('Paiement sécurisé par Mobile Money (MoneyFusion). Les jours s\'ajoutent à ton abonnement en cours.',
            style: TextStyle(color: K.muted, fontSize: 12.5)),
        SizedBox(height: 12),
        for (final p in kPlans) _planTile(p),
        SizedBox(height: 18),
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

/// Attente du paiement : vérifie toutes les 5 s (le serveur vérifie auprès de MoneyFusion).
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

/// Pendant la création du paiement (le serveur peut mettre jusqu'à une minute à se réveiller).
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
    final msg = _s < 6
        ? 'Patiente un instant…'
        : _s < 25
            ? 'Connexion au serveur sécurisé, encore quelques secondes…'
            : 'Le serveur se réveille, cela peut prendre jusqu\'à une minute. Ne ferme pas l\'application.';
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
            Text('Paiement sécurisé MoneyFusion', style: TextStyle(color: K.muted, fontSize: 12)),
          ]),
        ]),
      ),
    );
  }
}
