import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

void main() {
  runApp(const IPTVApp());
}

class IPTVApp extends StatelessWidget {
  const IPTVApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IPTV Player',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      home: const TelaLogin(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// ==================== MODELO DE CANAL ====================
class CanalModel {
  final String nome;
  final String logo;
  final String url;

  CanalModel({required this.nome, required this.logo, required this.url});
}

// ==================== PARSER DA LISTA M3U ====================
Future<List<CanalModel>> baixarEProcessarM3U(String urlLista) async {
  try {
    final response = await http.get(Uri.parse(urlLista));
    List<CanalModel> canais = [];

    if (response.statusCode == 200) {
      final linhas = response.body.split('\n');
      String nome = '';
      String logo = '';

      for (var linha in linhas) {
        linha = linha.trim();
        if (linha.startsWith('#EXTINF:')) {
          final partesVirgula = linha.split(',');
          if (partesVirgula.length > 1) {
            nome = partesVirgula.last;
          }
          if (linha.contains('tvg-logo="')) {
            try {
              final startIndex = linha.indexOf('tvg-logo="') + 10;
              final endIndex = linha.indexOf('"', startIndex);
              if (endIndex != -1) {
                logo = linha.substring(startIndex, endIndex);
              }
            } catch (_) {}
          }
        } else if (linha.isNotEmpty && !linha.startsWith('#')) {
          canais.add(CanalModel(
            nome: nome.isEmpty ? 'Canal sem nome' : nome,
            logo: logo,
            url: linha,
          ));
          nome = '';
          logo = '';
        }
      }
    }
    return canais;
  } catch (e) {
    return [];
  }
}

// ==================== TELA DE LOGIN ====================
class TelaLogin extends StatefulWidget {
  const TelaLogin({super.key});

  @override
  State<TelaLogin> createState() => _TelaLoginState();
}

class _TelaLoginState extends State<TelaLogin> {
  final _controller = TextEditingController(
    text: 'https://iptv-org.github.io/iptv/index.m3u', // Lista pública de teste
  );
  bool _carregando = false;

  void _carregarLista() async {
    String url = _controller.text.trim();
    if (url.isEmpty) return;

    setState(() => _carregando = true);

    var canais = await baixarEProcessarM3U(url);

    setState(() => _carregando = false);

    if (!mounted) return;

    if (canais.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TelaCanais(canais: canais),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao carregar lista ou lista vazia.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('IPTV - Configurar Lista')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.tv, size: 80, color: Colors.blueAccent),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'URL da Lista M3U',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _carregando ? null : _carregarLista,
                child: _carregando
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Carregar Canais', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== TELA DE LISTA DE CANAIS ====================
class TelaCanais extends StatelessWidget {
  final List<CanalModel> canais;

  const TelaCanais({super.key, required this.canais});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Canais Disponíveis (${canais.length})')),
      body: ListView.builder(
        itemCount: canais.length,
        itemBuilder: (context, index) {
          final canal = canais[index];
          return ListTile(
            leading: canal.logo.isNotEmpty
                ? Image.network(
                    canal.logo,
                    width: 40,
                    height: 40,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.tv, size: 40),
                  )
                : const Icon(Icons.tv, size: 40),
            title: Text(canal.nome, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(canal.url, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey)),
            trailing: const Icon(Icons.play_arrow, color: Colors.green),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TelaPlayer(canal: canal),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ==================== TELA DO PLAYER DE VÍDEO ====================
class TelaPlayer extends StatefulWidget {
  final CanalModel canal;

  const TelaPlayer({super.key, required this.canal});

  @override
  State<TelaPlayer> createState() => _TelaPlayerState();
}

class _TelaPlayerState extends State<TelaPlayer> {
  late VideoPlayerController _controller;
  bool _inicializado = false;
  bool _erro = false;

  @override
  void initState() {
    super.initState();
    _inicializarPlayer();
  }

  void _inicializarPlayer() {
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.canal.url))
      ..initialize().then((_) {
        setState(() {
          _inicializado = true;
          _controller.play();
        });
      }).catchError((error) {
        setState(() {
          _erro = true;
        });
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.canal.nome)),
      body: Center(
        child: _erro
            ? const Text('Erro ao reproduzir este canal.', style: TextStyle(color: Colors.red, fontSize: 18))
            : _inicializado
                ? AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: VideoPlayer(_controller),
                  )
                : const CircularProgressIndicator(),
      ),
    );
  }
}
