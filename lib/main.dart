import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:translator/translator.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

Future<void> requestMicrophonePermission() async {
  var status = await Permission.microphone.status;
  if (!status.isGranted) {
    await Permission.microphone.request();
  }
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        textTheme: GoogleFonts.poppinsTextTheme(),
        scaffoldBackgroundColor: const Color(0xFFF4F6F8),
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late TextEditingController inputController;
  late TextEditingController outputController;
  final translator = GoogleTranslator();
  final FlutterTts flutterTts = FlutterTts();
  late stt.SpeechToText speech;

  String inputLanguage = 'en';
  String outputLanguage = 'ha';
  bool isListening = false;
  bool isTranslating = false;
  bool isSpeaking = false;

  @override
  void initState() {
    super.initState();
    // await requestMicrophonePermission();
    initializeAsyncStuff();
    inputController = TextEditingController();
    outputController = TextEditingController(text: "Result here...");
    speech = stt.SpeechToText();
    flutterTts.setPitch(1.0);
    flutterTts.setSpeechRate(0.5);
  }

  @override
  void dispose() {
    inputController.dispose();
    outputController.dispose();
    speech.stop();
    super.dispose();
  }

  Future<void> initializeAsyncStuff() async {
    await requestMicrophonePermission();
  }

  Future<void> translateText() async {
    if (inputController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter text to translate.")),
      );
      return;
    }
    setState(() {
      isTranslating = true;
    });
    final inputText = inputController.text;
    final translated = await translator.translate(
      inputText,
      from: inputLanguage,
      to: outputLanguage,
    );
    setState(() {
      outputController.text = translated.text;
      isTranslating = false;
    });
  }

  String hausaToPhonetics(String text) {
    return text
        .replaceAll("gida", "geeda")
        .replaceAll("zamu", "zamu")
        .replaceAll("ka", "kaa")
        .replaceAll("tafi", "tafee")
        .replaceAll("na", "naa")
        .replaceAll("dake", "daakay");
  }

  Future<void> speakText() async {
    String toSpeak = outputController.text;
    if (outputLanguage == 'ha') {
      await flutterTts.setLanguage('en-US');
      toSpeak = hausaToPhonetics(toSpeak);
    } else {
      await flutterTts.setLanguage('en');
    }
    await flutterTts.speak(toSpeak);
  }

  Future<void> listenToSpeech() async {
    bool available = await speech.initialize(
      onStatus: (status) => {
        if (status == 'listening')
          {setState(() => isListening = true)}
        else if (status == 'notListening')
          {setState(() => isListening = false)},
      },
      onError: (error) => {
        print("Error: $error"),
        setState(() => isListening = false),
      },
    );

    if (available) {
      setState(() => isListening = true);
      speech.listen(
        onResult: (result) {
          setState(() {
            inputController.text = result.recognizedWords;
          });
        },
      );
    }
  }

  void stopListening() {
    speech.stop();
    setState(() => isListening = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Voice Translator"),
        centerTitle: true,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              TextField(
                controller: inputController,
                maxLines: 4,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  hintText: "Type or speak something...",
                  suffixIcon: IconButton(
                    icon: Icon(
                      isListening ? Icons.mic : Icons.mic_none,
                      color: isListening ? Colors.red : Colors.blue,
                    ),
                    onPressed: () async {
                      if (isListening) {
                        stopListening();
                      } else {
                        await listenToSpeech();
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  DropdownButton<String>(
                    value: inputLanguage,
                    onChanged: (newValue) =>
                        setState(() => inputLanguage = newValue!),
                    items: const [
                      DropdownMenuItem(value: 'en', child: Text('English')),
                      DropdownMenuItem(value: 'ha', child: Text('Hausa')),
                    ],
                  ),
                  const Icon(Icons.arrow_forward),
                  DropdownButton<String>(
                    value: outputLanguage,
                    onChanged: (newValue) =>
                        setState(() => outputLanguage = newValue!),
                    items: const [
                      DropdownMenuItem(value: 'en', child: Text('English')),
                      DropdownMenuItem(value: 'ha', child: Text('Hausa')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.translate),
                label: isTranslating
                    ? const Text("Translating...")
                    : const Text("Translate"),
                onPressed: isTranslating
                    ? null
                    : () async {
                        await translateText();
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                icon: const Icon(Icons.volume_up),
                label: isSpeaking
                    ? const Text("Speaking...")
                    : const Text("Speak"),
                onPressed: isSpeaking
                    ? null
                    : () async {
                        setState(() => isSpeaking = true);
                        await speakText();
                        setState(() => isSpeaking = false);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blue,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: outputController,
                maxLines: 5,
                readOnly: true,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: "Translation Output",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
