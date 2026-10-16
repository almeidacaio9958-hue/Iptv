import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
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
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1F1F1F),
          elevation: 0,
        ),
      ),
      home: const TelaLogin(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// ==================== MODELO DE CANAL ====================
class CanalModel {
  final String id;
  final String nome;
  final String logo;
  final String url;
  final String categoria;

  CanalModel({
    required this.id,
    required this.nome,
    required this.logo,
    required this.url,
    this.categoria = 'Geral',
  });
}

// ==================== PARSER M3U & XTREAM ====================
Future<List<CanalModel>> baixarEProcessarM3U(String urlLista) async {
  try {
    final response = await http.get(Uri.parse(urlLista));
    List<CanalModel> canais = [];

    if (response.statusCode == 200) {
      final linhas = response.body.split('\n');
      String nome = '';
      String logo = '';
      String categoria = 'Geral';

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
              if (endIndex != -1) logo = linha.substring(startIndex, endIndex);
            } catch (_) {}
          }
          if (linha.contains('group-title="')) {
            try {
              final startIndex = linha.indexOf('group-title="') + 13;
              final endIndex = linha.indexOf('"', startIndex);
              if (endIndex != -1) categoria = linha.substring(startIndex, endIndex);
            } catch (_) {}
          }
        } else if (linha.isNotEmpty && !linha.startsWith('#')) {
          canais.add(CanalModel(
            id: linha,
            nome: nome.isEmpty ? 'Canal sem nome' : nome,
            logo: logo,
            url: linha,
            categoria: categoria.isEmpty ? 'Geral' : categoria,
          ));
          nome = '';
          logo = '';
          categoria = 'Geral';
        }
      }
    }
    return canais;
  } catch (e) {
    return [];
  }
}

Future<List<CanalModel>> carregarXtreamCodes(String server, String user, String pass) async {
  try {
    String cleanServer = server.endsWith('/') ? server.substring(0, server.length - 1) : server;
    final url = Uri.parse('$cleanServer/player_api.php?username=$user&password=$pass&action=get_live_streams');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      List data = json.decode(response.body);
      return data.map((item) {
        String streamId = item['stream_id'].toString();
        String streamUrl = '$cleanServer/live/$user/$pass/$streamId.m3u8';
        return CanalModel(
          id: streamId,
          nome: item['name'] ?? 'Sem nome',
          logo: item['stream_icon'] ?? '',
          url: streamUrl,
          categoria: item['category_name'] ?? 'Geral',
        );
      }).toList();
    }
    return [];
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

class _TelaLoginState extends State<TelaLogin> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _urlM3uController = TextEditingController(text: 'https://iptv-org.github.io/iptv/index.m3u');
  
  final _serverController = TextEditingController();
  final _userController = TextEditingController();
  final _passController = TextEditingController();

  bool _carregando = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  void _entrarM3U() async {
    String url = _urlM3uController.text.trim();
    if (url.isEmpty) return;

    setState(() => _carregando = true);
    var canais = await baixarEProcessarM3U(url);
    setState(() => _carregando = false);

    _navegarParaCanais(canais);
  }

  void _entrarXtream() async {
    String server = _serverController.text.trim();
    String user = _userController.text.trim();
    String pass = _passController.text.trim();

    if (server.isEmpty || user.isEmpty || pass.isEmpty) return;

    setState(() => _carregando = true);
    var canais = await carregarXtreamCodes(server, user, pass);
    setState(() => _carregando = false);

    _navegarParaCanais(canais);
  }

  void _navegarParaCanais(List<CanalModel> canais) {
    if (!mounted) return;
    if (canais.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => TelaPrincipal(todosCanais: canais)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Falha ao carregar canais. Verifique os dados.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('IPTV Player Pro'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Lista M3U'),
            Tab(text: 'Xtream API'),
          ],
        ),
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // Aba M3U
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextField(
                        controller: _urlM3uController,
                        decoration: const InputDecoration(
                          labelText: 'URL M3U',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.link),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _entrarM3U,
                        style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                        child: const Text('Carregar Lista'),
                      ),
                    ],
                  ),
                ),
                // Aba Xtream Codes
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        TextField(
                          controller: _serverController,
                          decoration: const InputDecoration(
                            labelText: 'URL do Servidor (ex: http://servidor.com:8080)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.dns),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _userController,
                          decoration: const InputDecoration(
                            labelText: 'Usuário',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _passController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Senha',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.lock),
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _entrarXtream,
                          style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                          child: const Text('Entrar'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// ==================== TELA PRINCIPAL (CATEGORIAS E FAVORITOS) ====================
class TelaPrincipal extends StatefulWidget {
  final List<CanalModel> todosCanais;

  const TelaPrincipal({super.key, required this.todosCanais});

  @override
  State<TelaPrincipal> createState() => _TelaPrincipalState();
}

class _TelaPrincipalState extends State<TelaPrincipal> {
  List<String> _favoritosIds = [];
  String _categoriaSelecionada = 'Todas';

  @override
  void initState() {
    super.initState();
    _carregarFavoritos();
  }

  void _carregarFavoritos() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _favoritosIds = prefs.getStringList('favoritos') ?? [];
    });
  }

  void _toggleFavorito(String id) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_favoritosIds.contains(id)) {
        _favoritosIds.remove(id);
      } else {
        _favoritosIds.add(id);
      }
    });
    await prefs.setStringList('favoritos', _favoritosIds);
  }

  @override
  Widget build(BuildContext context) {
    List<String> categorias = ['Todas', 'Favoritos'];
    var categoriasM3U = widget.todosCanais.map((c) => c.categoria).toSet().toList();
    categoriasM3U.sort();
    categorias.addAll(categoriasM3U);

    List<CanalModel> canaisExibidos = widget.todosCanais.where((canal) {
      if (_categoriaSelecionada == 'Todas') return true;
      if (_categoriaSelecionada == 'Favoritos') return _favoritosIds.contains(canal.id);
      return canal.categoria == _categoriaSelecionada;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Canais (${canaisExibidos.length})'),
      ),
      body: Row(
        children: [
          Container(
            width: 140,
            color: const Color(0xFF1E1E1E),
            child: ListView.builder(
              itemCount: categorias.length,
              itemBuilder: (context, index) {
                final cat = categorias[index];
                final selecionado = cat == _categoriaSelecionada;
                return ListTile(
                  title: Text(
                    cat,
                    style: TextStyle(
                      color: selecionado ? Colors.blueAccent : Colors.white,
                      fontWeight: selecionado ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                  selected: selecionado,
                  onTap: () {
                    setState(() => _categoriaSelecionada = cat);
                  },
                );
              },
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: canaisExibidos.length,
              itemBuilder: (context, index) {
                final canal = canaisExibidos[index];
                final ehFavorito = _favoritosIds.contains(canal.id);

                return ListTile(
                  leading: canal.logo.isNotEmpty
                      ? Image.network(
                          canal.logo,
                          width: 40,
                          height: 40,
                          errorBuilder: (_, __, ___) => const Icon(Icons.tv),
                        )
                      : const Icon(Icons.tv),
                  title: Text(canal.nome, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(canal.categoria, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: IconButton(
                    icon: Icon(
                      ehFavorito ? Icons.star : Icons.star_border,
                      color: ehFavorito ? Colors.amber : Colors.grey,
                    ),
                    onPressed: () => _toggleFavorito(canal.id),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => TelaPlayer(canal: canal)),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== TELA PLAYER DE VÍDEO ====================
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
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.canal.url))
      ..initialize().then((_) {
        setState(() {
          _inicializado = true;
          _controller.play();
        });
      }).catchError((_) {
        setState(() => _erro = true);
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
      backgroundColor: Colors.black,
      appBar: AppBar(title: Text(widget.canal.nome)),
      body: Center(
        child: _erro
            ? const Text('Erro ao reproduzir o canal.', style: TextStyle(color: Colors.red))
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
