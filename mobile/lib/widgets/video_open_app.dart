import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import '../services/analytics.dart';
import '../services/highlights.dart';
import '../services/hl_player.dart';
import '../l10n/tr.dart';

const _ch = MethodChannel('kounadia/video');

Future<void> _external(HlVideo v) async {
  try {
    await launchUrl(Uri.parse(v.url), mode: LaunchMode.externalApplication);
  } catch (_) {}
}

/// Temps forts : lecteur YouTube officiel dans KOUNADIA (en haut de l'écran), sinon l'app YouTube.
Future<void> openHighlight(BuildContext context, HlVideo v, {String? title}) async {
  Analytics.log('hl_open', {'e': v.embed ? 1 : 0});
  if (!v.embed) {
    await _external(v);
    return;
  }
  HlPlayer.play(v, title: title);
}

/// Place le lecteur au-dessus de toute l'app (posé dans MaterialApp.builder).
class HlPlayerHost extends StatefulWidget {
  final Widget child;
  HlPlayerHost({super.key, required this.child});

  @override
  State<HlPlayerHost> createState() => _HlPlayerHostState();
}

class _HlPlayerHostState extends State<HlPlayerHost> {
  WebViewController? _c;
  String? _loaded;
  bool _ready = false;
  bool _failed = false;
  bool _miniTools = false;
  double _rate = 1;
  Timer? _slow;
  // Réglage par glissement : luminosité (gauche) ou volume (droite).
  String? _adj;
  double _adjV = 0;
  Timer? _adjHide;

  @override
  void initState() {
    super.initState();
    HlPlayer.current.addListener(_onVideo);
    HlPlayer.mode.addListener(_onMode);
    HlPlayer.pip.addListener(_re);
    _ch.setMethodCallHandler((c) async {
      if (c.method == 'pip') HlPlayer.pip.value = c.arguments == true;
      return null;
    });
  }

  @override
  void dispose() {
    HlPlayer.current.removeListener(_onVideo);
    HlPlayer.mode.removeListener(_onMode);
    HlPlayer.pip.removeListener(_re);
    _slow?.cancel();
    super.dispose();
  }

  void _re() {
    if (mounted) setState(() {});
  }

  String _html(String id) => '''<!DOCTYPE html><html><head>
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1">
<meta name="referrer" content="strict-origin-when-cross-origin">
<style>html,body{margin:0;padding:0;height:100%;background:#000;overflow:hidden}#p{position:absolute;top:0;left:0;width:100%;height:100%}</style>
</head><body><div id="p"></div>
<script>
var p=null;
var tag=document.createElement('script');tag.src='https://www.youtube.com/iframe_api';document.head.appendChild(tag);
function onYouTubeIframeAPIReady(){
  p=new YT.Player('p',{width:'100%',height:'100%',videoId:'$id',
    playerVars:{playsinline:1,rel:0,fs:0,autoplay:1,modestbranding:1,origin:'https://kounadia.pages.dev'},
    events:{onReady:function(e){K.postMessage('ready');try{e.target.playVideo();}catch(x){}},
            onError:function(e){K.postMessage('err:'+e.data);}}});
}
function rate(r){try{p.setPlaybackRate(r);}catch(x){}}
function pause(){try{p.pauseVideo();}catch(x){}}
</script></body></html>''';

  void _onVideo() {
    final v = HlPlayer.current.value;
    _slow?.cancel();
    if (v == null) {
      _c?.runJavaScript('pause()').catchError((_) {});
      _c = null;
      _loaded = null;
      _ch.invokeMethod('allowPip', false).catchError((_) => null);
      _exitFull();
      _re();
      return;
    }
    if (_loaded == v.id && _c != null) {
      _re();
      return;
    }
    _loaded = v.id;
    _ready = false;
    _failed = false;
    _rate = 1;
    final c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..addJavaScriptChannel('K', onMessageReceived: (m) {
        if (!mounted) return;
        if (m.message == 'ready') {
          setState(() => _ready = true);
        } else if (m.message.startsWith('err')) {
          Analytics.log('hl_err', {'c': m.message});
          setState(() => _failed = true);
        }
      })
      ..setNavigationDelegate(NavigationDelegate(onNavigationRequest: (r) {
        // Lien vers YouTube (titre, logo) : ouvert dans l'app YouTube.
        if (r.isMainFrame && !r.url.startsWith('https://kounadia.pages.dev') && r.url != 'about:blank') {
          launchUrl(Uri.parse(r.url), mode: LaunchMode.externalApplication).catchError((_) => false);
          return NavigationDecision.prevent;
        }
        return NavigationDecision.navigate;
      }))
      ..loadHtmlString(_html(v.id), baseUrl: 'https://kounadia.pages.dev/');
    final p = c.platform;
    if (p is AndroidWebViewController) p.setMediaPlaybackRequiresUserGesture(false);
    _c = c;
    _ch.invokeMethod('allowPip', true).catchError((_) => null);
    _slow = Timer(Duration(seconds: 20), () {
      if (mounted && !_ready) setState(() => _failed = true);
    });
    _re();
  }

  void _onMode() {
    if (HlPlayer.mode.value == 'full') {
      SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      _exitFull();
    }
    _re();
  }

  void _exitFull() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    Future.delayed(Duration(seconds: 2), () => SystemChrome.setPreferredOrientations(DeviceOrientation.values));
  }

  void _setRate() {
    const rates = [1.0, 1.25, 1.5, 2.0, 0.75];
    _rate = rates[(rates.indexOf(_rate) + 1) % rates.length];
    _c?.runJavaScript('rate($_rate)').catchError((_) {});
    _re();
  }

  String get _rateTxt => '${_rate.toString().replaceAll(RegExp(r'\.0$'), '')}x';

  Future<void> _adjStart(String what) async {
    try {
      final v = await _ch.invokeMethod<double>(what == 'b' ? 'getBrightness' : 'getVolume');
      _adjV = (v ?? 0.5).clamp(0.0, 1.0);
    } catch (_) {
      _adjV = 0.5;
    }
    _adjHide?.cancel();
    setState(() => _adj = what);
  }

  void _adjMove(DragUpdateDetails d, double h) {
    if (_adj == null) return;
    _adjV = (_adjV - d.delta.dy / (h * 0.9)).clamp(0.0, 1.0);
    _ch.invokeMethod(_adj == 'b' ? 'setBrightness' : 'setVolume', _adjV).catchError((_) => null);
    setState(() {});
  }

  void _adjEnd() {
    _adjHide?.cancel();
    _adjHide = Timer(Duration(milliseconds: 700), () {
      if (mounted) setState(() => _adj = null);
    });
  }

  Widget _strip(String what, double h) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragStart: (_) => _adjStart(what),
        onVerticalDragUpdate: (d) => _adjMove(d, h),
        onVerticalDragEnd: (_) => _adjEnd(),
        child: SizedBox(width: 44, height: h),
      );

  // Pas d'infobulle : le lecteur est au-dessus du navigateur de pages (pas d'Overlay pour l'afficher).
  Widget _btn(IconData i, String tip, VoidCallback f, {double size = 22}) => IconButton(
        visualDensity: VisualDensity.compact,
        icon: Icon(i, color: Colors.white, size: size),
        onPressed: f,
      );

  Widget _overlays(double vh) {
    final v = HlPlayer.current.value!;
    return Stack(children: [
      if (!_ready && !_failed) Center(child: CircularProgressIndicator(color: Colors.white)),
      if (_failed)
        Positioned.fill(
          child: Container(
            color: Colors.black,
            alignment: Alignment.center,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              T('Cette vidéo se regarde dans YouTube.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
              SizedBox(height: 10),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Color(0xFFFF0000)),
                onPressed: () => _external(v),
                icon: Icon(Icons.play_arrow_rounded),
                label: T('Ouvrir dans YouTube'),
              ),
            ]),
          ),
        ),
      if (_adj != null)
        Center(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: Colors.black.withAlpha(170), borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(_adj == 'b' ? Icons.brightness_6_rounded : Icons.volume_up_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('${(_adjV * 100).round()} %', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            ]),
          ),
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final v = HlPlayer.current.value;
    final mode = HlPlayer.mode.value;
    final pip = HlPlayer.pip.value;
    final size = mq.size;
    final on = v != null && _c != null;
    final dock = on && mode == 'dock' && !pip;
    final topPad = mq.padding.top;
    final vh = size.width * 9 / 16;
    const bar = 40.0;
    final dockH = topPad + vh + bar;

    // Contenu de l'app : poussé sous la vidéo quand elle est en haut.
    final app = Positioned(
      top: dock ? dockH : 0,
      left: 0,
      right: 0,
      bottom: 0,
      child: MediaQuery(
        data: dock ? mq.copyWith(padding: mq.padding.copyWith(top: 0), viewPadding: mq.viewPadding.copyWith(top: 0)) : mq,
        child: widget.child,
      ),
    );
    if (!on) return Stack(children: [app]);

    // Zone du lecteur selon le mode.
    late Rect box, video;
    if (pip || mode == 'full') {
      box = Offset.zero & size;
      video = Offset.zero & size;
    } else if (mode == 'mini') {
      const w = 224.0, h = w * 9 / 16;
      box = Rect.fromLTWH(size.width - w - 12, size.height - h - mq.padding.bottom - 84, w, h);
      video = Offset.zero & Size(w, h);
    } else {
      box = Rect.fromLTWH(0, 0, size.width, dockH);
      video = Rect.fromLTWH(0, topPad, size.width, vh);
    }

    final tools = <Widget>[];
    if (!pip && mode == 'dock') {
      tools.add(Positioned(
        top: topPad + vh,
        left: 0,
        right: 0,
        height: bar,
        child: Container(
          color: Color(0xFF0B0B12),
          padding: EdgeInsets.only(left: 12),
          child: Row(children: [
            Icon(Icons.play_circle_fill_rounded, color: Color(0xFFFF3B30), size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(HlPlayer.title,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
            ),
            TextButton(
              onPressed: _setRate,
              style: TextButton.styleFrom(foregroundColor: Colors.white, minimumSize: Size(40, 32), padding: EdgeInsets.symmetric(horizontal: 6)),
              child: Text(_rateTxt, style: TextStyle(fontWeight: FontWeight.w900)),
            ),
            _btn(Icons.picture_in_picture_alt_rounded, 'Réduire', () => HlPlayer.mode.value = 'mini', size: 20),
            _btn(Icons.fullscreen_rounded, 'Plein écran', () => HlPlayer.mode.value = 'full'),
            _btn(Icons.close_rounded, 'Fermer', HlPlayer.close),
          ]),
        ),
      ));
    }
    if (!pip && (mode == 'dock' || mode == 'full')) {
      // Bords de la vidéo : glisser vers le haut / le bas pour la luminosité (gauche) et le volume (droite).
      tools.add(Positioned(left: video.left, top: video.top + 40, child: _strip('b', video.height - 80)));
      tools.add(Positioned(right: 0, top: video.top + 40, child: _strip('v', video.height - 80)));
    }
    if (!pip && mode == 'full') {
      tools.add(Positioned(
        top: 8,
        left: 8,
        child: SafeArea(
          child: Container(
            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _btn(Icons.fullscreen_exit_rounded, 'Quitter le plein écran', () => HlPlayer.mode.value = 'dock'),
              TextButton(
                onPressed: _setRate,
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: Text(_rateTxt, style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ]),
          ),
        ),
      ));
    }
    if (!pip && mode == 'mini') {
      tools.add(Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => setState(() => _miniTools = !_miniTools),
          child: !_miniTools
              ? SizedBox.expand()
              : Container(
                  color: Colors.black45,
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    _btn(Icons.open_in_full_rounded, 'Agrandir', () {
                      _miniTools = false;
                      HlPlayer.mode.value = 'dock';
                    }),
                    _btn(Icons.close_rounded, 'Fermer', () {
                      _miniTools = false;
                      HlPlayer.close();
                    }),
                  ]),
                ),
        ),
      ));
    }

    return Stack(children: [
      app,
      Positioned.fromRect(
        rect: box,
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: Material(
          color: Colors.black,
          elevation: mode == 'mini' && !pip ? 10 : 0,
          borderRadius: mode == 'mini' && !pip ? BorderRadius.circular(12) : null,
          clipBehavior: Clip.antiAlias,
          child: Stack(children: [
            Positioned.fromRect(rect: video, child: WebViewWidget(key: ValueKey(_loaded), controller: _c!)),
            Positioned.fromRect(rect: video, child: _overlays(video.height)),
            ...tools,
          ]),
          ),
        ),
      ),
    ]);
  }
}
