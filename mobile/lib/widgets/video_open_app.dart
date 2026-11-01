import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import '../services/analytics.dart';
import '../services/highlights.dart';
import '../l10n/tr.dart';

Future<void> _external(HlVideo v) async {
  try {
    await launchUrl(Uri.parse(v.url), mode: LaunchMode.externalApplication);
  } catch (_) {}
}

/// Temps forts : lecture dans KOUNADIA (lecteur YouTube officiel), sinon dans l'app YouTube.
Future<void> openHighlight(BuildContext context, HlVideo v, {String? title}) async {
  Analytics.log('hl_open', {'e': v.embed ? 1 : 0});
  if (!v.embed) {
    await _external(v);
    return;
  }
  await Navigator.push(context, MaterialPageRoute(builder: (_) => VideoScreen(video: v, title: title)));
}

class VideoScreen extends StatefulWidget {
  final HlVideo video;
  final String? title;
  VideoScreen({super.key, required this.video, this.title});

  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  late final WebViewController _c;
  bool _ready = false;
  bool _failed = false;
  bool _full = false;
  Timer? _slow;
  final _pk = GlobalKey();

  String get _html => '''<!DOCTYPE html><html><head>
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1">
<meta name="referrer" content="strict-origin-when-cross-origin">
<style>html,body{margin:0;padding:0;height:100%;background:#000;overflow:hidden}#p{position:absolute;top:0;left:0;width:100%;height:100%}</style>
</head><body><div id="p"></div>
<script>
var tag=document.createElement('script');tag.src='https://www.youtube.com/iframe_api';document.head.appendChild(tag);
function onYouTubeIframeAPIReady(){
  new YT.Player('p',{width:'100%',height:'100%',videoId:'${widget.video.id}',
    playerVars:{playsinline:1,rel:0,fs:0,autoplay:1,modestbranding:1,origin:'https://kounadia.pages.dev'},
    events:{onReady:function(e){K.postMessage('ready');try{e.target.playVideo();}catch(x){}},
            onError:function(e){K.postMessage('err:'+e.data);}}});
}
</script></body></html>''';

  @override
  void initState() {
    super.initState();
    _c = WebViewController()
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
        // Lien vers YouTube (titre, logo) : ouvert dans l'app YouTube, KOUNADIA reste ici.
        if (r.isMainFrame && !r.url.startsWith('https://kounadia.pages.dev') && r.url != 'about:blank') {
          launchUrl(Uri.parse(r.url), mode: LaunchMode.externalApplication).catchError((_) => false);
          return NavigationDecision.prevent;
        }
        return NavigationDecision.navigate;
      }))
      ..loadHtmlString(_html, baseUrl: 'https://kounadia.pages.dev/');
    final p = _c.platform;
    if (p is AndroidWebViewController) p.setMediaPlaybackRequiresUserGesture(false);
    _slow = Timer(Duration(seconds: 20), () {
      if (mounted && !_ready) setState(() => _failed = true);
    });
  }

  @override
  void dispose() {
    _slow?.cancel();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _toggleFull() {
    setState(() => _full = !_full);
    if (_full) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      Future.delayed(Duration(seconds: 2), () => SystemChrome.setPreferredOrientations(DeviceOrientation.values));
    }
  }

  Widget _player() => KeyedSubtree(key: _pk, child: _playerBody());

  Widget _playerBody() => Stack(children: [
        Positioned.fill(child: WebViewWidget(controller: _c)),
        if (!_ready && !_failed) Center(child: CircularProgressIndicator(color: Colors.white)),
        if (_failed)
          Positioned.fill(
            child: Container(
              color: Colors.black,
              padding: EdgeInsets.all(20),
              alignment: Alignment.center,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                T('Cette vidéo se regarde dans YouTube.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                SizedBox(height: 12),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Color(0xFFFF0000)),
                  onPressed: () => _external(widget.video),
                  icon: Icon(Icons.play_arrow_rounded),
                  label: T('Ouvrir dans YouTube'),
                ),
              ]),
            ),
          ),
      ]);

  @override
  Widget build(BuildContext context) {
    final land = MediaQuery.of(context).orientation == Orientation.landscape;
    if (land || _full) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(children: [
          Positioned.fill(child: _player()),
          Positioned(
            top: 8,
            left: 8,
            child: SafeArea(
              child: IconButton(
                style: IconButton.styleFrom(backgroundColor: Colors.black54),
                icon: Icon(_full ? Icons.fullscreen_exit_rounded : Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => _full ? _toggleFull() : Navigator.pop(context),
              ),
            ),
          ),
        ]),
      );
    }
    final v = widget.video;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: T('Temps forts', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(tooltip: tr('Plein écran'), icon: Icon(Icons.fullscreen_rounded), onPressed: _toggleFull),
        ],
      ),
      body: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AspectRatio(aspectRatio: 16 / 9, child: _player()),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Text(v.title.isNotEmpty ? v.title : (widget.title ?? ''),
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, height: 1.3)),
          ),
          if (v.channel.isNotEmpty)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Icon(Icons.verified_rounded, color: Colors.white70, size: 16),
                SizedBox(width: 6),
                Expanded(
                  child: Text('${tr('Chaîne officielle')} : ${v.channel}',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                ),
              ]),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: BorderSide(color: Colors.white38)),
              onPressed: () => _external(v),
              icon: Icon(Icons.open_in_new_rounded, size: 18),
              label: T('Ouvrir dans YouTube'),
            ),
          ),
        ]),
      ),
    );
  }
}
