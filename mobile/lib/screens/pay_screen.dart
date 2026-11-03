import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/account.dart';
import '../services/analytics.dart';
import '../widgets/forecast_card.dart' show K;
import '../l10n/tr.dart';

/// Indicatif téléphonique des pays en F CFA.
const _dial = {'BF': '226', 'BJ': '229', 'CI': '225', 'SN': '221', 'TG': '228', 'ML': '223', 'NE': '227', 'GW': '245'};

String _price(int v) => '${v.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ' ')} F';

/// Paiement dans KOUNADIA : pays, moyen de paiement, numéro. La demande arrive sur le téléphone de l'abonné.
/// Renvoie true (payé), 'hosted' (autre moyen : page de paiement) ou null.
class PayScreen extends StatefulWidget {
  final KPlan plan;
  final List<PayCountry> countries;
  PayScreen({super.key, required this.plan, required this.countries});

  @override
  State<PayScreen> createState() => _PayScreenState();
}

enum _Step { form, wait, paid, failed }

class _PayScreenState extends State<PayScreen> with WidgetsBindingObserver {
  late PayCountry _c = widget.countries.firstWhere((c) => c.iso == 'BF', orElse: () => widget.countries.first);
  PayNet? _net;
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  bool _busy = false;
  bool _needOtp = false;
  String? _err;
  _Step _step = _Step.form;
  String _token = '';
  String _info = '';
  Timer? _t;
  int _n = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restore();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _t?.cancel();
    _phone.dispose();
    _otp.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed && _step == _Step.wait) _check();
  }

  /// Le dernier pays, moyen et numéro utilisés sont proposés de nouveau.
  Future<void> _restore() async {
    try {
      final p = await SharedPreferences.getInstance();
      final cc = p.getString('k_pay_cc'), net = p.getString('k_pay_net'), ph = p.getString('k_pay_phone');
      final c = widget.countries.where((x) => x.iso == cc).firstOrNull;
      if (!mounted) return;
      setState(() {
        if (c != null) _c = c;
        _net = _c.nets.where((n) => n.code == net).firstOrNull;
        if (ph != null && _phone.text.isEmpty) _phone.text = ph;
      });
    } catch (_) {}
  }

  Future<void> _remember() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('k_pay_cc', _c.iso);
      if (_net != null) await p.setString('k_pay_net', _net!.code);
      await p.setString('k_pay_phone', _phone.text.trim());
    } catch (_) {}
  }

  /// Nom court du moyen de paiement (« Orange Burkina Faso » → « Orange »).
  String _short(PayNet n) {
    var s = n.name.replaceAll(_c.name, '').replaceAll(RegExp(r'\b(CI|BF|BJ|SN|TG|ML|NE|GW|Burkina|Faso)\b'), '').trim();
    s = s.replaceAll(RegExp(r'\s+'), ' ');
    return s.isEmpty ? n.name : s;
  }

  /// Numéro au format international (+226…), quel que soit ce que l'abonné a tapé.
  String? _intl() {
    final d = _dial[_c.iso] ?? '';
    var x = _phone.text.replaceAll(RegExp(r'[^\d]'), '');
    if (x.startsWith('00')) x = x.substring(2);
    if (d.isNotEmpty && x.startsWith(d) && x.length > d.length + 6) x = x.substring(d.length);
    if (x.length < 7 || x.length > 10) return null;
    return '+$d$x';
  }

  Future<void> _pay() async {
    if (_net == null) {
      setState(() => _err = tr('Choisis ton moyen de paiement.'));
      return;
    }
    final ph = _intl();
    if (ph == null) {
      setState(() => _err = tr('Numéro invalide.'));
      return;
    }
    final otp = _otp.text.replaceAll(RegExp(r'\s'), '');
    if (_needOtp && otp.length < 4) {
      setState(() => _err = tr('Entre le code de paiement.'));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      final r = await Account.startDirect(widget.plan.id, _net!.code, ph, otp: _needOtp ? otp : null);
      if (!mounted) return;
      if (r['needOtp'] == true && r['token'] == null) {
        setState(() {
          _busy = false;
          _needOtp = true;
          _err = tr('Ce moyen de paiement demande un code. Entre-le puis touche « Payer ».');
        });
        return;
      }
      _remember();
      Analytics.log('pay_start', {'plan': widget.plan.id, 'net': _net!.code, 'mode': 'direct'});
      _token = '${r['token']}';
      _info = ['${r['message'] ?? ''}', '${r['instructions'] ?? ''}'].where((x) => x.trim().isNotEmpty).toSet().join('\n');
      _otp.clear();
      setState(() {
        _busy = false;
        _needOtp = false;
        _step = _Step.wait;
        _n = 0;
      });
      _t?.cancel();
      _t = Timer.periodic(Duration(seconds: 4), (_) => _check());
      final url = '${r['url'] ?? ''}';
      if (url.startsWith('https://')) {
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => _PayWeb(url: url)));
        _check();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _err = e.toString();
        });
      }
    }
  }

  Future<void> _check() async {
    if (_step != _Step.wait || _token.isEmpty) return;
    if (++_n > 90) {
      _t?.cancel(); // 6 minutes : l'abonné peut vérifier à la main
      return;
    }
    try {
      final r = await Account.paymentCheck(_token);
      if (!mounted || _step != _Step.wait) return;
      final st = '${r['status']}';
      setState(() {
        if (st == 'paid') {
          _step = _Step.paid;
          _t?.cancel();
          Analytics.log('pay_success', {'plan': widget.plan.id, 'mode': 'direct'});
        } else if (st == 'failure' || st == 'error') {
          _step = _Step.failed;
          _t?.cancel();
        } else if (r['needOtp'] == true) {
          _needOtp = true;
          final i = '${r['instructions'] ?? ''}'.trim();
          if (i.isNotEmpty) _info = i;
        }
      });
    } catch (_) {}
  }

  Future<void> _sendOtp() async {
    final otp = _otp.text.replaceAll(RegExp(r'\s'), '');
    if (otp.length < 4) {
      setState(() => _err = tr('Entre le code de paiement.'));
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      final r = await Account.confirmOtp(_token, otp);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _needOtp = false;
        if (r['status'] == 'paid') {
          _step = _Step.paid;
          _t?.cancel();
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _err = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (did, _) {
        if (did) _t?.cancel();
      },
      child: Scaffold(
        backgroundColor: K.bg,
        appBar: AppBar(
          backgroundColor: K.bg,
          surfaceTintColor: Colors.transparent,
          foregroundColor: K.text,
          title: T('Paiement', style: TextStyle(fontWeight: FontWeight.w900)),
        ),
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: Duration(milliseconds: 250),
            child: switch (_step) {
              _Step.form => _form(),
              _Step.wait => _wait(),
              _Step.paid => _end(true),
              _Step.failed => _end(false),
            },
          ),
        ),
      ),
    );
  }

  Widget _summary() => Container(
        padding: EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)]),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              T('KOUNADIA Premium', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w700)),
              SizedBox(height: 2),
              T(widget.plan.label, style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
            ]),
          ),
          Text(_price(widget.plan.price), style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
        ]),
      );

  Widget _label(String s) => Padding(
        padding: EdgeInsets.fromLTRB(2, 22, 2, 10),
        child: T(s, style: TextStyle(color: K.text, fontSize: 14.5, fontWeight: FontWeight.w800)),
      );

  InputDecoration _dec(String hint, {Widget? prefix, IconData? icon}) => InputDecoration(
        hintText: tr(hint),
        hintStyle: TextStyle(color: K.muted),
        prefixIcon: icon != null ? Icon(icon, color: K.muted) : null,
        prefix: prefix,
        filled: true,
        fillColor: K.card,
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: K.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: K.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: K.indigo, width: 1.6)),
      );

  Widget _form() {
    final dial = _dial[_c.iso] ?? '';
    return ListView(key: ValueKey('form'), padding: EdgeInsets.fromLTRB(16, 4, 16, 28), children: [
      _summary(),
      _label('Pays'),
      DropdownButtonFormField<String>(
        key: ValueKey('cc${_c.iso}'),
        initialValue: _c.iso,
        isExpanded: true,
        dropdownColor: K.card,
        borderRadius: BorderRadius.circular(14),
        style: TextStyle(color: K.text, fontSize: 15, fontWeight: FontWeight.w600),
        decoration: _dec('Pays', icon: Icons.public_rounded),
        items: [for (final c in widget.countries) DropdownMenuItem(value: c.iso, child: Text(c.name))],
        onChanged: _busy
            ? null
            : (v) => setState(() {
                  _c = widget.countries.firstWhere((c) => c.iso == v);
                  _net = null;
                  _needOtp = false;
                  _err = null;
                }),
      ),
      _label('Moyen de paiement'),
      LayoutBuilder(builder: (_, box) {
        final w = (box.maxWidth - 10) / 2;
        return Wrap(spacing: 10, runSpacing: 10, children: [
          for (final n in _c.nets) SizedBox(width: w, child: _netTile(n)),
        ]);
      }),
      _label('Numéro Mobile Money'),
      TextField(
        controller: _phone,
        enabled: !_busy,
        keyboardType: TextInputType.phone,
        autofillHints: [AutofillHints.telephoneNumberNational],
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d +]'))],
        style: TextStyle(color: K.text, fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: .5),
        decoration: _dec('Ton numéro',
            icon: Icons.phone_iphone_rounded,
            prefix: Text('+$dial  ', style: TextStyle(color: K.muted, fontSize: 17, fontWeight: FontWeight.w700))),
      ),
      if (_needOtp) ...[
        _label('Code de paiement'),
        _otpField(),
      ],
      if (_err != null) ...[
        SizedBox(height: 14),
        _note(_err!, K.red, Icons.info_rounded),
      ],
      SizedBox(height: 22),
      FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: K.indigo,
          minimumSize: Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: _busy ? null : _pay,
        child: _busy
            ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.6))
            : Text('${tr('Payer')} ${_price(widget.plan.price)}', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900)),
      ),
      SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.lock_rounded, color: K.green, size: 15),
        SizedBox(width: 6),
        Flexible(child: T('Paiement sécurisé. Premium activé dès la confirmation.', style: TextStyle(color: K.muted, fontSize: 12.5))),
      ]),
      SizedBox(height: 18),
      Center(
        child: TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, 'hosted'),
          child: T('Autre moyen de paiement (carte bancaire…)', style: TextStyle(color: K.indigoText, fontWeight: FontWeight.w700)),
        ),
      ),
    ]);
  }

  Widget _netTile(PayNet n) {
    final on = _net?.code == n.code;
    final name = _short(n);
    return Material(
      color: on ? K.indigoSoft : K.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _busy
            ? null
            : () => setState(() {
                  _net = n;
                  _needOtp = false;
                  _err = null;
                }),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: on ? K.indigo : K.border, width: on ? 1.8 : 1),
          ),
          child: Row(children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: on ? K.indigo : K.groupHead, shape: BoxShape.circle),
              child: Text(name.isEmpty ? '•' : name.characters.first.toUpperCase(),
                  style: TextStyle(color: on ? Colors.white : K.text, fontWeight: FontWeight.w900, fontSize: 15)),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: K.text, fontSize: 14, fontWeight: on ? FontWeight.w800 : FontWeight.w600)),
            ),
            if (on) Icon(Icons.check_circle_rounded, color: K.indigoText, size: 20),
          ]),
        ),
      ),
    );
  }

  Widget _otpField() => TextField(
        controller: _otp,
        enabled: !_busy,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(8)],
        style: TextStyle(color: K.text, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 4),
        decoration: _dec('Code reçu ou généré', icon: Icons.password_rounded),
      );

  Widget _note(String s, Color c, IconData i) => Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(color: c.withAlpha(28), borderRadius: BorderRadius.circular(12)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(i, color: c, size: 18),
          SizedBox(width: 8),
          Expanded(child: Text(s, style: TextStyle(color: K.text, fontSize: 13.5, height: 1.35))),
        ]),
      );

  /// Code USSD présent dans les instructions (ex. *144*…#), pour le composer d'un geste.
  String? get _ussd => RegExp(r'\*[\d*]+#').firstMatch(_info)?.group(0);

  Widget _wait() {
    final code = _ussd;
    return ListView(key: ValueKey('wait'), padding: EdgeInsets.fromLTRB(16, 4, 16, 28), children: [
      _summary(),
      SizedBox(height: 30),
      Center(child: SizedBox(width: 54, height: 54, child: CircularProgressIndicator(color: K.indigo, strokeWidth: 4))),
      SizedBox(height: 18),
      T('Valide le paiement sur ton téléphone',
          textAlign: TextAlign.center, style: TextStyle(color: K.text, fontSize: 19, fontWeight: FontWeight.w900)),
      SizedBox(height: 6),
      T('${_net != null ? _short(_net!) : ''} · ${_intl() ?? ''}',
          textAlign: TextAlign.center, style: TextStyle(color: K.indigoText, fontSize: 14, fontWeight: FontWeight.w800)),
      SizedBox(height: 18),
      if (_info.isNotEmpty)
        Container(
          padding: EdgeInsets.all(14),
          decoration: BoxDecoration(color: K.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: K.border)),
          child: SelectableText(_info, style: TextStyle(color: K.text, fontSize: 14, height: 1.45)),
        )
      else
        T('Une demande de paiement arrive sur ton téléphone. Entre ton code secret Mobile Money pour confirmer.',
            textAlign: TextAlign.center, style: TextStyle(color: K.muted, fontSize: 14, height: 1.45)),
      if (code != null) ...[
        SizedBox(height: 12),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: Size.fromHeight(46)),
          icon: Icon(Icons.dialpad_rounded),
          label: Text('${tr('Composer')} $code'),
          onPressed: () => launchUrl(Uri.parse('tel:${Uri.encodeComponent(code)}')),
        ),
      ],
      if (_needOtp) ...[
        _label('Code de paiement'),
        _otpField(),
        SizedBox(height: 10),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: K.indigo, minimumSize: Size.fromHeight(48)),
          onPressed: _busy ? null : _sendOtp,
          child: T('Valider le code'),
        ),
      ],
      if (_err != null) ...[
        SizedBox(height: 12),
        _note(_err!, K.red, Icons.info_rounded),
      ],
      SizedBox(height: 18),
      OutlinedButton(
        style: OutlinedButton.styleFrom(minimumSize: Size.fromHeight(46)),
        onPressed: () {
          _n = 0;
          _t?.cancel();
          _t = Timer.periodic(Duration(seconds: 4), (_) => _check());
          _check();
        },
        child: T("J'ai validé, vérifier maintenant"),
      ),
      SizedBox(height: 8),
      TextButton(
        onPressed: () => setState(() {
          _t?.cancel();
          _step = _Step.form;
          _err = null;
        }),
        child: T('Changer de numéro ou de moyen', style: TextStyle(color: K.muted)),
      ),
    ]);
  }

  Widget _end(bool ok) => ListView(key: ValueKey('end$ok'), padding: EdgeInsets.fromLTRB(16, 40, 16, 28), children: [
        Icon(ok ? Icons.verified_rounded : Icons.error_rounded, color: ok ? K.green : K.red, size: 72),
        SizedBox(height: 16),
        T(ok ? 'Premium activé 🎉' : 'Paiement non abouti',
            textAlign: TextAlign.center, style: TextStyle(color: K.text, fontSize: 22, fontWeight: FontWeight.w900)),
        SizedBox(height: 8),
        T(ok ? 'Merci ! Tous les contenus KOUNADIA sont débloqués.' : 'Aucun montant validé. Tu peux réessayer.',
            textAlign: TextAlign.center, style: TextStyle(color: K.muted, fontSize: 14.5, height: 1.4)),
        SizedBox(height: 26),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: ok ? K.green : K.indigo,
              minimumSize: Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          onPressed: () => ok
              ? Navigator.pop(context, true)
              : setState(() {
                  _step = _Step.form;
                  _err = null;
                }),
          child: T(ok ? 'Continuer' : 'Réessayer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        ),
      ]);
}

/// Page de validation du moyen de paiement (carte, Wave…), affichée dans KOUNADIA.
class _PayWeb extends StatefulWidget {
  final String url;
  _PayWeb({required this.url});

  @override
  State<_PayWeb> createState() => _PayWebState();
}

class _PayWebState extends State<_PayWeb> {
  late final WebViewController _c;
  int _p = 0;

  @override
  void initState() {
    super.initState();
    _c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) {
          if (mounted) setState(() => _p = p);
        },
        onNavigationRequest: (r) {
          final u = r.url;
          // Retour vers KOUNADIA : on ferme, l'app vérifie le paiement.
          if (u.contains('/kounadia/pay/return')) {
            if (mounted) Navigator.pop(context);
            return NavigationDecision.prevent;
          }
          // Application de paiement (Wave, Orange…) ou appel : ouverte par le téléphone.
          if (!u.startsWith('http')) {
            launchUrl(Uri.parse(u), mode: LaunchMode.externalApplication).catchError((_) => false);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: K.bg,
        appBar: AppBar(
          backgroundColor: K.bg,
          surfaceTintColor: Colors.transparent,
          foregroundColor: K.text,
          title: T('Validation du paiement', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          bottom: _p < 100 ? PreferredSize(preferredSize: Size.fromHeight(2), child: LinearProgressIndicator(value: _p / 100, minHeight: 2, color: K.indigo)) : null,
        ),
        body: WebViewWidget(controller: _c),
      );
}

/// Page de paiement AlphaPay affichée dans KOUNADIA (Orange, Moov, carte…), avec vérification automatique.
/// L'abonnement s'active seulement quand le serveur a vérifié le paiement auprès d'AlphaPay.
class HostedPayPage extends StatefulWidget {
  final String token, url;
  final KPlan plan;
  HostedPayPage({super.key, required this.token, required this.url, required this.plan});

  @override
  State<HostedPayPage> createState() => _HostedPayPageState();
}

class _HostedPayPageState extends State<HostedPayPage> with WidgetsBindingObserver {
  late final WebViewController _c;
  Timer? _t;
  int _p = 0, _n = 0;
  bool _paid = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) {
          if (mounted) setState(() => _p = p);
        },
        onNavigationRequest: (r) {
          final u = r.url;
          // Fin du paiement : retour vers KOUNADIA, on vérifie tout de suite.
          if (u.contains('/kounadia/pay/return')) {
            _check();
            return NavigationDecision.prevent;
          }
          // Code USSD, appel, application Wave/Orange… : ouverts par le téléphone.
          if (!u.startsWith('http')) {
            launchUrl(Uri.parse(u), mode: LaunchMode.externalApplication).catchError((_) => false);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(Uri.parse(widget.url));
    _t = Timer.periodic(Duration(seconds: 4), (_) => _check());
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
    if (_paid) return;
    if (++_n > 225) {
      _t?.cancel(); // 15 minutes
      return;
    }
    try {
      final st = await Account.paymentStatus(widget.token);
      if (!mounted || st != 'paid') return;
      _t?.cancel();
      Analytics.log('pay_success', {'plan': widget.plan.id, 'mode': 'page'});
      setState(() => _paid = true);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: K.bg,
      appBar: AppBar(
        backgroundColor: K.bg,
        surfaceTintColor: Colors.transparent,
        foregroundColor: K.text,
        titleSpacing: 0,
        leading: IconButton(icon: Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context, _paid)),
        title: Row(children: [
          Icon(Icons.lock_rounded, color: K.green, size: 18),
          SizedBox(width: 6),
          Expanded(child: T('Paiement sécurisé', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
        ]),
        actions: [
          // Secours : si la page ne s'affiche pas bien ici, l'ouvrir dans le navigateur (la vérification continue).
          IconButton(
            tooltip: tr('Ouvrir dans le navigateur'),
            icon: Icon(Icons.open_in_new_rounded, size: 20),
            onPressed: () => launchUrl(Uri.parse(widget.url), mode: LaunchMode.externalApplication),
          ),
          Container(
            margin: EdgeInsets.only(right: 14),
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: K.indigoSoft, borderRadius: BorderRadius.circular(20)),
            child: Text('${tr(widget.plan.label)} · ${_price(widget.plan.price)}',
                style: TextStyle(color: K.indigoText, fontSize: 12.5, fontWeight: FontWeight.w800)),
          ),
        ],
        bottom: _p < 100 && !_paid
            ? PreferredSize(preferredSize: Size.fromHeight(2), child: LinearProgressIndicator(value: _p / 100, minHeight: 2, color: K.indigo))
            : null,
      ),
      body: _paid ? _done() : WebViewWidget(controller: _c),
      bottomNavigationBar: _paid
          ? null
          : SafeArea(
              child: Container(
                padding: EdgeInsets.fromLTRB(16, 10, 16, 10),
                decoration: BoxDecoration(color: K.card, border: Border(top: BorderSide(color: K.border))),
                child: Row(children: [
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: K.indigo)),
                  SizedBox(width: 10),
                  Expanded(
                    child: T('Premium activé automatiquement dès la confirmation.',
                        style: TextStyle(color: K.muted, fontSize: 12.5, fontWeight: FontWeight.w600)),
                  ),
                  TextButton(onPressed: () {
                    _n = 0;
                    _check();
                  }, child: T('Vérifier', style: TextStyle(color: K.indigoText, fontWeight: FontWeight.w800))),
                ]),
              ),
            ),
    );
  }

  Widget _done() => Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(color: K.green.withAlpha(30), shape: BoxShape.circle),
              child: Icon(Icons.verified_rounded, color: K.green, size: 60),
            ),
            SizedBox(height: 20),
            T('Premium activé 🎉', textAlign: TextAlign.center, style: TextStyle(color: K.text, fontSize: 24, fontWeight: FontWeight.w900)),
            SizedBox(height: 8),
            T('Merci ! Tous les contenus KOUNADIA sont débloqués.',
                textAlign: TextAlign.center, style: TextStyle(color: K.muted, fontSize: 15, height: 1.4)),
            SizedBox(height: 28),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: K.green,
                  minimumSize: Size.fromHeight(54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              onPressed: () => Navigator.pop(context, true),
              child: T('Continuer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            ),
          ]),
        ),
      );
}
