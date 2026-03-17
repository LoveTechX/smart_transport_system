import 'package:flutter/material.dart';

import '../models/bus_routes_repository.dart';
import '../services/smart_transport_ai_service.dart';
import '../widgets/app_backdrop.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final List<_ChatMessage> _messages = <_ChatMessage>[];
  final TextEditingController _controller = TextEditingController();
  final SmartTransportAIService _ai = SmartTransportAIService.instance;
  _BotLanguage _activeLanguage = _BotLanguage.english;
  _ReplyLanguage _replyLanguage = _ReplyLanguage.english;
  String _languageIndicator = 'Detected: English';

  static const List<String> _quickActions = <String>[
    'App Overview',
    'Set English',
    'Set Hindi',
    'Set Punjabi',
    'Passenger Help',
    'Driver Help',
    'Conductor Help',
    'Routes & Schedule',
    'Ticket & Fare',
    'Tracking & ETA',
    'SOS / Emergency',
    'Login Problems',
    'AI Features',
  ];

  @override
  void initState() {
    super.initState();
    _messages.add(
      _ChatMessage.bot(_welcomeText()),
    );
    _messages.add(_ChatMessage.bot(_buildAppOverview()));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _sendMessage([String? preset]) {
    final text = (preset ?? _controller.text).trim();
    if (text.isEmpty) return;

    final switched = _applyLanguageChange(text.toLowerCase());
    if (!switched) {
      _replyLanguage = _detectReplyLanguage(text);
      _languageIndicator = 'Detected: ${_replyLanguage.label}';
    } else {
      _languageIndicator = 'Detected: ${_replyLanguage.label} (manual)';
    }

    setState(() {
      _messages.add(_ChatMessage.user(text));
      if (switched) {
        _messages.add(_ChatMessage.bot(_languageChangedText()));
      } else {
        _messages.add(_ChatMessage.bot(_generateReply(text)));
      }
    });

    if (preset == null) {
      _controller.clear();
    }
  }

  bool _applyLanguageChange(String q) {
    if (q.contains('set english') || q.contains('english language')) {
      _activeLanguage = _BotLanguage.english;
      _replyLanguage = _ReplyLanguage.english;
      return true;
    }
    if (q.contains('set hindi') ||
        q.contains('hindi language') ||
        q.contains('hindi me') ||
        q.contains('hindi mein')) {
      _activeLanguage = _BotLanguage.hindi;
      _replyLanguage = _ReplyLanguage.hinglish;
      return true;
    }
    if (q.contains('set punjabi') ||
        q.contains('punjabi language') ||
        q.contains('punjabi vich')) {
      _activeLanguage = _BotLanguage.punjabi;
      _replyLanguage = _ReplyLanguage.punjabi;
      return true;
    }
    return false;
  }

  _ReplyLanguage _detectReplyLanguage(String input) {
    final text = input.trim();
    final q = text.toLowerCase();

    final hasGurmukhi = RegExp(r'[\u0A00-\u0A7F]').hasMatch(text);
    if (hasGurmukhi) return _ReplyLanguage.punjabi;

    final hasDevanagari = RegExp(r'[\u0900-\u097F]').hasMatch(text);
    if (hasDevanagari) return _ReplyLanguage.hindi;

    final punjabiWords = <String>{
      'tusi',
      'tuhada',
      'tuhanu',
      'kive',
      'kida',
      'kinna',
      'kehri',
      'kedi',
      'vich',
      'naal',
      'nall',
      'sakde',
      'hovega',
      'kr',
      'kar',
      'ds',
      'daso',
      'haanji',
      'ji',
      'vekh',
      'pucho',
      'menu',
      'mainu',
      'chahida',
    };

    final hinglishWords = <String>{
      'kya',
      'kaise',
      'kyu',
      'kyon',
      'mujhe',
      'mera',
      'meri',
      'hai',
      'nahi',
      'karna',
      'karni',
      'batao',
      'dikhao',
      'kaunsa',
      'kaunsi',
      'chal',
      'chahiye',
      'karo',
      'karke',
      'jaldi',
      'samajh',
      'chalu',
      'wala',
    };

    final englishWords = <String>{
      'what',
      'which',
      'where',
      'when',
      'how',
      'route',
      'bus',
      'time',
      'help',
      'ticket',
      'fare',
      'schedule',
      'driver',
      'passenger',
      'details',
      'show',
      'tell',
    };

    final words =
        RegExp(r'[a-z]+').allMatches(q).map((m) => m.group(0)!).toList();

    int punjabiScore = 0;
    int hinglishScore = 0;
    int englishScore = 0;

    for (final w in words) {
      if (punjabiWords.contains(w)) punjabiScore++;
      if (hinglishWords.contains(w)) hinglishScore++;
      if (englishWords.contains(w)) englishScore++;
    }

    final looksMixed = punjabiScore > 0 && hinglishScore > 0;
    if (looksMixed) {
      return _ReplyLanguage.hinglish;
    }

    if (punjabiScore >= 2 && punjabiScore >= hinglishScore) {
      return _ReplyLanguage.punjabi;
    }
    if (hinglishScore >= 2) return _ReplyLanguage.hinglish;

    if (englishScore >= 2 && punjabiScore == 0 && hinglishScore == 0) {
      return _ReplyLanguage.english;
    }

    switch (_activeLanguage) {
      case _BotLanguage.hindi:
        return _ReplyLanguage.hinglish;
      case _BotLanguage.punjabi:
        return _ReplyLanguage.punjabi;
      case _BotLanguage.english:
        return _ReplyLanguage.english;
    }
  }

  String _localize({
    required String en,
    required String hi,
    required String pa,
  }) {
    switch (_replyLanguage) {
      case _ReplyLanguage.hindi:
        return hi;
      case _ReplyLanguage.hinglish:
        return hi;
      case _ReplyLanguage.punjabi:
        return pa;
      case _ReplyLanguage.english:
        return en;
    }
  }

  String _welcomeText() {
    return _localize(
      en: 'Welcome! I am Smart Transport AI assistant. Ask about routes, buses, timings, fares, tickets, ETA, SOS, or app features.',
      hi: 'Namaste! Main Smart Transport AI sahayak hoon. Aap route, bus, timing, fare, ticket, ETA, SOS ya app features puch sakte hain.',
      pa: 'Sat Sri Akal! Main Smart Transport AI madadgaar haan. Tusi route, bus, time, fare, ticket, ETA, SOS ya app features puch sakde ho.',
    );
  }

  String _languageChangedText() {
    if (_replyLanguage == _ReplyLanguage.english) {
      return 'Language updated to English.';
    }
    if (_replyLanguage == _ReplyLanguage.punjabi) {
      return 'Language Punjabi vich set ho gayi hai.';
    }
    if (_replyLanguage == _ReplyLanguage.hindi ||
        _replyLanguage == _ReplyLanguage.hinglish) {
      return 'Language Hindi/Hinglish me set ho gayi hai.';
    }
    return 'Language updated.';
  }

  String _buildAppOverview() {
    final routes = BusRoutesRepository.allRoutes;
    final total = routes.length;
    final fares = routes.map((r) => r.fare).toList()..sort();
    final minFare = fares.isEmpty ? 0 : fares.first.toInt();
    final maxFare = fares.isEmpty ? 0 : fares.last.toInt();
    final languages = _ai.supportedLanguages().join(', ');

    return _localize(
      en: 'App Info Summary:\n'
          '- Name: Smart Transport System\n'
          '- Roles: Passenger, Driver, Conductor, Admin Control\n'
          '- Total routes in app data: $total\n'
          '- Fare range: Rs $minFare - Rs $maxFare\n'
          '- Key modules: Live Tracking, Routes, Schedule, Tickets, Alerts, Profile, AI Features\n'
          '- Languages supported: $languages\n'
          '- Help screens: AI Help Center and Chatbot\n\n'
          'Tip: Ask "full app guide" to see all major workflows.',
      hi: 'App jankari:\n'
          '- Naam: Smart Transport System\n'
          '- Roles: Passenger, Driver, Conductor, Admin Control\n'
          '- Total routes: $total\n'
          '- Fare range: Rs $minFare - Rs $maxFare\n'
          '- Main modules: Live Tracking, Routes, Schedule, Tickets, Alerts, Profile, AI Features\n'
          '- Supported languages: $languages\n\n'
          'Tip: "full app guide" puch kar complete workflow dekhiye.',
      pa: 'App di jankari:\n'
          '- Naam: Smart Transport System\n'
          '- Roles: Passenger, Driver, Conductor, Admin Control\n'
          '- Kul routes: $total\n'
          '- Fare range: Rs $minFare - Rs $maxFare\n'
          '- Main modules: Live Tracking, Routes, Schedule, Tickets, Alerts, Profile, AI Features\n'
          '- Supported languages: $languages\n\n'
          'Tip: "full app guide" pucho te poora workflow vekho.',
    );
  }

  String _topRouteSnapshot() {
    final routes = BusRoutesRepository.allRoutes.take(8).toList();
    if (routes.isEmpty) {
      return _localize(
        en: 'No route data is available right now.',
        hi: 'Abhi route data uplabdh nahi hai.',
        pa: 'Hun route data uplabdh nahi hai.',
      );
    }
    final lines = routes
        .map((r) =>
            'Bus ${r.routeNumber}: ${r.source} -> ${r.destination} | ETA ${r.estimatedMinutes} min | Fare Rs ${r.fare.toInt()}')
        .join('\n');
    return _localize(
      en: 'Available bus-route-time data:\n$lines\n\nAsk like: "bus 204" or "from city center to suburban hub".',
      hi: 'Uplabdh bus-route-time data:\n$lines\n\nAise puchiye: "bus 204" ya "from city center to suburban hub".',
      pa: 'Uplabdh bus-route-time data:\n$lines\n\nEh tarah pucho: "bus 204" ya "from city center to suburban hub".',
    );
  }

  bool _looksLikeRouteQuery(String q) {
    return q.contains('route') ||
        q.contains('bus') ||
        q.contains('time') ||
        q.contains('timing') ||
        q.contains('samay') ||
        q.contains('kaunsi') ||
        q.contains('kaunsa') ||
        q.contains('eta') ||
        q.contains('from') ||
        q.contains('to') ||
        q.contains('kehri') ||
        q.contains('kedi') ||
        q.contains('ja rhi') ||
        q.contains('ja rahi') ||
        q.contains('kis route') ||
        q.contains('which route');
  }

  List<dynamic> _findRouteMatches(String q) {
    final all = BusRoutesRepository.allRoutes;
    final numberMatch = RegExp(r'\b\d{3}\b').firstMatch(q);
    if (numberMatch != null) {
      final number = numberMatch.group(0)!;
      return all.where((r) => r.routeNumber == number).take(6).toList();
    }

    final stopWords = <String>{
      'which',
      'route',
      'bus',
      'buses',
      'time',
      'timing',
      'eta',
      'from',
      'to',
      'the',
      'is',
      'are',
      'for',
      'me',
      'tell',
      'please',
      'kehri',
      'kedi',
      'ki',
      'kehda',
      'ja',
      'rhi',
      'rahi',
      'hai',
      'h',
      'te',
      'nu',
      'vich',
    };

    final tokens = q
        .split(RegExp(r'[^a-z0-9]+'))
        .where((t) => t.length > 2 && !stopWords.contains(t))
        .toList();

    if (tokens.isEmpty) {
      return all.take(8).toList();
    }

    final scored = <Map<String, dynamic>>[];
    for (final route in all) {
      final haystackMain =
          '${route.routeNumber} ${route.name} ${route.source} ${route.destination}'
              .toLowerCase();
      int score = 0;
      for (final token in tokens) {
        if (haystackMain.contains(token)) {
          score += 3;
        }
        final stopHit = route.stops.any(
          (s) => s.stopName.toLowerCase().contains(token),
        );
        if (stopHit) score += 1;
      }
      if (score > 0) {
        scored.add({'route': route, 'score': score});
      }
    }

    scored.sort((a, b) {
      final s = (b['score'] as int).compareTo(a['score'] as int);
      if (s != 0) return s;
      return (a['route'] as dynamic)
          .estimatedMinutes
          .compareTo((b['route'] as dynamic).estimatedMinutes);
    });

    return scored.map((e) => e['route']).take(8).toList();
  }

  String _formatRouteMatches(String q) {
    final matches = _findRouteMatches(q);
    if (matches.isEmpty) {
      return _localize(
        en: 'No matching route found. Try bus number (example: 204) or source-destination names.',
        hi: 'Koi matching route nahi mila. Bus number (jaise 204) ya source-destination naam try kariye.',
        pa: 'Koi matching route nahi milya. Bus number (jiven 204) ya source-destination naam try karo.',
      );
    }

    final lines = matches.map((r) {
      final firstStop = r.stops.isNotEmpty ? r.stops.first.stopName : r.source;
      final lastStop =
          r.stops.isNotEmpty ? r.stops.last.stopName : r.destination;
      return 'Bus ${r.routeNumber} | ${r.source} -> ${r.destination} | Time ${r.estimatedMinutes} min | Fare Rs ${r.fare.toInt()} | Start $firstStop | End $lastStop';
    }).join('\n');

    return _localize(
      en: 'Matched bus routes:\n$lines',
      hi: 'Matched bus routes:\n$lines',
      pa: 'Matched bus routes:\n$lines',
    );
  }

  String _roleGuidance() {
    return _localize(
      en: 'Role-wise guidance:\n'
          '- Passenger: Track bus, view routes/schedule, book/manage tickets, alerts, profile, history.\n'
          '- Driver: Navigation, bus status, trips, location sharing, safety updates.\n'
          '- Conductor: Ticket verification, seat and crowd updates, onboard support.\n'
          '- Admin Control: Fleet monitoring, delay handling, route updates, emergency coordination.',
      hi: 'Role-wise guidance:\n'
          '- Passenger: Track bus, route/schedule dekho, ticket book/manage karo.\n'
          '- Driver: Navigation, bus status, trips, location sharing updates.\n'
          '- Conductor: Ticket verify karo, seat aur crowd updates rakho.\n'
          '- Admin Control: Fleet monitor karo, delays aur route changes handle karo.',
      pa: 'Role-wise guidance:\n'
          '- Passenger: Track bus, routes/schedule vekho, ticket book/manage karo.\n'
          '- Driver: Navigation, bus status, trips, location sharing updates.\n'
          '- Conductor: Ticket verify karo, seat te crowd updates sambhalo.\n'
          '- Admin Control: Fleet monitor karo, delays te route changes handle karo.',
    );
  }

  String _fullAppGuide() {
    final aiFeatures = _ai.projectAiFeatureChecklist().take(6).join('\n- ');
    return _localize(
      en: 'Full App Guide:\n'
          '1) Start from Role Selection and login with your role.\n'
          '2) Passenger workflow: Track Bus -> Routes/Schedule -> Ticket -> My Tickets -> Alerts/History.\n'
          '3) Driver workflow: Navigation -> Bus Status -> Trips -> Safety + Location updates.\n'
          '4) Conductor workflow: Verify tickets -> seat availability -> passenger support.\n'
          '5) Emergency workflow: SOS -> share location -> notify control room/police.\n'
          '6) AI capabilities in app include:\n- $aiFeatures\n\n'
          'If you tell me your role, I can give a step-by-step guide for only that role.',
      hi: 'Full App Guide:\n'
          '1) Role Selection se shuru karke apne role se login kariye.\n'
          '2) Passenger workflow: Track Bus -> Routes/Schedule -> Ticket -> My Tickets -> Alerts/History.\n'
          '3) Driver workflow: Navigation -> Bus Status -> Trips -> Safety + Location updates.\n'
          '4) Conductor workflow: Ticket verify -> seat status -> passenger support.\n'
          '5) Emergency workflow: SOS -> location share -> control room/police notify.\n'
          '6) AI capabilities:\n- $aiFeatures',
      pa: 'Full App Guide:\n'
          '1) Role Selection ton start karo te apne role naal login karo.\n'
          '2) Passenger workflow: Track Bus -> Routes/Schedule -> Ticket -> My Tickets -> Alerts/History.\n'
          '3) Driver workflow: Navigation -> Bus Status -> Trips -> Safety + Location updates.\n'
          '4) Conductor workflow: Ticket verify -> seat status -> passenger support.\n'
          '5) Emergency workflow: SOS -> location share -> control room/police notify.\n'
          '6) AI capabilities:\n- $aiFeatures',
    );
  }

  String _generateReply(String input) {
    final q = input.toLowerCase().trim();

    if (_looksLikeRouteQuery(q)) {
      return _formatRouteMatches(q);
    }

    if (q.contains('all information') ||
        q.contains('app info') ||
        q.contains('full app guide') ||
        q.contains('overview')) {
      return '${_buildAppOverview()}\n\n${_roleGuidance()}';
    }

    if (q.contains('passenger')) {
      return _localize(
        en: 'Passenger Help:\n'
            '- Use Track Bus for live bus position and ETA.\n'
            '- Use Routes/Schedule to plan trip.\n'
            '- Use Ticket + My Tickets for booking and management.\n'
            '- Use Alerts for delays and route changes.\n'
            '- Use Profile/History for account and trip records.',
        hi: 'Passenger Help:\n'
            '- Track Bus se live bus position aur ETA dekhiye.\n'
            '- Routes/Schedule se trip plan kijiye.\n'
            '- Ticket + My Tickets se booking manage kijiye.\n'
            '- Alerts me delay aur route changes milenge.',
        pa: 'Passenger Help:\n'
            '- Track Bus naal live bus position te ETA vekho.\n'
            '- Routes/Schedule naal trip plan karo.\n'
            '- Ticket + My Tickets naal booking manage karo.\n'
            '- Alerts vich delay te route updates milange.',
      );
    }

    if (q.contains('driver')) {
      return _localize(
        en: 'Driver Help:\n'
            '- Open Navigation for route guidance.\n'
            '- Update bus status regularly (on time, delayed, stopped).\n'
            '- Keep location sharing active for live tracking.\n'
            '- Use trips and settings modules for daily operations.',
        hi: 'Driver Help:\n'
            '- Navigation open karke route follow kariye.\n'
            '- Bus status regular update kariye.\n'
            '- Live tracking ke liye location sharing on rakhiye.',
        pa: 'Driver Help:\n'
            '- Navigation kholo te route follow karo.\n'
            '- Bus status regular update karo.\n'
            '- Live tracking layi location sharing on rakho.',
      );
    }

    if (q.contains('conductor')) {
      return _localize(
        en: 'Conductor Help:\n'
            '- Verify passenger tickets quickly.\n'
            '- Monitor occupied/available seats.\n'
            '- Help with fare/ticket issues and onboard support.',
        hi: 'Conductor Help:\n'
            '- Ticket verification jaldi kijiye.\n'
            '- Occupied/available seats monitor kijiye.\n'
            '- Fare aur ticket issue me support dijiye.',
        pa: 'Conductor Help:\n'
            '- Ticket verification jaldi karo.\n'
            '- Occupied/available seats monitor karo.\n'
            '- Fare te ticket issue vich support deo.',
      );
    }

    if (q.contains('route') || q.contains('schedule') || q.contains('stop')) {
      return _topRouteSnapshot();
    }

    if (q.contains('ticket') || q.contains('fare') || q.contains('seat')) {
      return _localize(
        en: 'Ticket & Fare Help:\n'
            '- Book ticket from Ticket screen.\n'
            '- Check booked entries in My Tickets.\n'
            '- Fare depends on selected route distance and type.\n'
            '- Seat availability updates in real time.',
        hi: 'Ticket & Fare Help:\n'
            '- Ticket screen se booking kariye.\n'
            '- My Tickets me booked tickets dekhiye.\n'
            '- Fare route distance aur type par depend karta hai.\n'
            '- Seat availability real time me update hoti hai.',
        pa: 'Ticket & Fare Help:\n'
            '- Ticket screen ton booking karo.\n'
            '- My Tickets vich booked tickets vekho.\n'
            '- Fare route distance te type te depend karda hai.\n'
            '- Seat availability real time vich update hovegi.',
      );
    }

    if (q.contains('track') ||
        q.contains('eta') ||
        q.contains('arrival') ||
        q.contains('delay')) {
      return _localize(
        en: 'Tracking & ETA Help:\n'
            '- Live bus location is available on map tracking screens.\n'
            '- ETA is AI-predicted using route, traffic and historical delays.\n'
            '- Delay alerts are pushed through notification/alerts modules.',
        hi: 'Tracking & ETA Help:\n'
            '- Live bus location map tracking screen me milti hai.\n'
            '- ETA AI model route, traffic aur history se predict karta hai.\n'
            '- Delay alerts app notifications me milte hain.',
        pa: 'Tracking & ETA Help:\n'
            '- Live bus location map tracking screen te mildi hai.\n'
            '- ETA AI model route, traffic te history de base te predict karda hai.\n'
            '- Delay alerts app notifications vich aunde ne.',
      );
    }

    if (q.contains('ai feature') || q.contains('ai')) {
      return _localize(
        en: 'AI Features in this app:\n- ${_ai.projectAiFeatureChecklist().join('\n- ')}',
        hi: 'App ke AI features:\n- ${_ai.projectAiFeatureChecklist().join('\n- ')}',
        pa: 'App de AI features:\n- ${_ai.projectAiFeatureChecklist().join('\n- ')}',
      );
    }

    if (q.contains('sos') ||
        q.contains('emergency') ||
        q.contains('police') ||
        q.contains('ambulance') ||
        q.contains('safety')) {
      return _localize(
        en: 'Emergency Help:\n'
            '- Use SOS immediately in urgent situations.\n'
            '- Share live location with control room.\n'
            '- Contact emergency services (police/ambulance) if required.\n'
            '- Keep bus ID and route number ready while reporting.',
        hi: 'Emergency Help:\n'
            '- Urgent situation me turant SOS use kariye.\n'
            '- Live location control room ko share kariye.\n'
            '- Zarurat ho to police/ambulance contact kariye.\n'
            '- Report karte waqt bus ID aur route number ready rakhiye.',
        pa: 'Emergency Help:\n'
            '- Urgent situation vich turant SOS use karo.\n'
            '- Live location control room naal share karo.\n'
            '- Zaroorat pawe ta police/ambulance contact karo.\n'
            '- Report karde time bus ID te route number ready rakho.',
      );
    }

    if (q.contains('login') ||
        q.contains('password') ||
        q.contains('account')) {
      return _localize(
        en: 'Login Help:\n'
            '- Ensure correct role and valid email/password.\n'
            '- Check internet connection and retry login.\n'
            '- Use reset password if needed.\n'
            '- If lockout happens after many attempts, wait and try again.',
        hi: 'Login Help:\n'
            '- Sahi role aur valid email/password use kariye.\n'
            '- Internet check karke dobara login kariye.\n'
            '- Zarurat ho to reset password use kariye.\n'
            '- Bahut attempts ke baad lock ho to thoda wait karke try kariye.',
        pa: 'Login Help:\n'
            '- Sahi role te valid email/password use karo.\n'
            '- Internet check karke dubara login karo.\n'
            '- Zaroorat hove ta reset password use karo.\n'
            '- Zyada attempts to baad lock hove ta thoda wait karke try karo.',
      );
    }

    if (q.contains('language') ||
        q.contains('bhasha') ||
        q.contains('punjabi') ||
        q.contains('hindi') ||
        q.contains('hinglish')) {
      return _localize(
        en: 'Supported chatbot styles: English, Hinglish, Hindi, Punjabi. Auto-detection is ON. You can still type: set english | set hindi | set punjabi.',
        hi: 'Supported chatbot styles: English, Hinglish, Hindi, Punjabi. Auto-detection ON hai. Aap type kar sakte hain: set english | set hindi | set punjabi.',
        pa: 'Supported chatbot styles: English, Hinglish, Hindi, Punjabi. Auto-detection ON hai. Tusi type kar sakde ho: set english | set hindi | set punjabi.',
      );
    }

    if (q.contains('help') || q.contains('guide')) {
      return _fullAppGuide();
    }

    return _localize(
      en: 'I can help with all app information. Try one of these:\n'
          '- App overview\n'
          '- Passenger help\n'
          '- Driver help\n'
          '- Routes and schedule\n'
          '- Ticket and fare\n'
          '- Tracking and ETA\n'
          '- SOS / emergency\n'
          '- AI features\n\n'
          'You can also type: "full app guide".',
      hi: 'Main app ki sari jankari me help kar sakta hoon. Inme se puchiye:\n'
          '- App overview\n'
          '- Passenger help\n'
          '- Driver help\n'
          '- Routes and schedule\n'
          '- Ticket and fare\n'
          '- Tracking and ETA\n'
          '- SOS / emergency\n'
          '- AI features',
      pa: 'Main app di sari jankari vich help kar sakda haan. Eh pucho:\n'
          '- App overview\n'
          '- Passenger help\n'
          '- Driver help\n'
          '- Routes and schedule\n'
          '- Ticket and fare\n'
          '- Tracking and ETA\n'
          '- SOS / emergency\n'
          '- AI features',
    );
  }

  Widget _quickActionChip(String text) {
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 8),
      child: ActionChip(
        label: Text(text),
        onPressed: () => _sendMessage(text),
      ),
    );
  }

  Widget _buildTopPanel(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary.withValues(alpha: 0.16),
            colorScheme.secondary.withValues(alpha: 0.14),
            const Color(0xFF16212B),
          ],
        ),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.smart_toy_rounded,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'AI Chat Assistant',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              _buildLanguagePill(context),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Ask in English, Hinglish, Hindi, or Punjabi. Get route, timing, fare, and role-based help instantly.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _quickActions.map(_quickActionChip).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguagePill(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF131E28),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF334252)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.translate_rounded, size: 14, color: colorScheme.tertiary),
          const SizedBox(width: 6),
          Text(
            _languageIndicator,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(BuildContext context, _ChatMessage message) {
    final isUser = message.isUser;
    final colorScheme = Theme.of(context).colorScheme;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? colorScheme.primary.withValues(alpha: 0.22)
              : const Color(0xFF17212B),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: Border.all(
            color: isUser
                ? colorScheme.primary.withValues(alpha: 0.38)
                : const Color(0xFF2E3C4A),
          ),
        ),
        child: Text(message.text),
      ),
    );
  }

  Widget _buildComposer(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: const BoxDecoration(
        color: Color(0xFF121A23),
        border: Border(top: BorderSide(color: Color(0xFF2A3846))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              onSubmitted: (_) => _sendMessage(),
              decoration: const InputDecoration(
                hintText: 'Ask route, time, fare, role, SOS, login help...',
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: IconButton(
              onPressed: _sendMessage,
              icon: const Icon(Icons.send_rounded),
              color: colorScheme.onPrimary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Transport AI Chatbot'),
      ),
      body: AppBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: _buildTopPanel(context),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF101923),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFF2A3948)),
                  ),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return _buildMessageBubble(context, message);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _buildComposer(context),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;

  const _ChatMessage({required this.text, required this.isUser});

  factory _ChatMessage.user(String text) {
    return _ChatMessage(text: text, isUser: true);
  }

  factory _ChatMessage.bot(String text) {
    return _ChatMessage(text: text, isUser: false);
  }
}

enum _BotLanguage {
  english,
  hindi,
  punjabi,
}

enum _ReplyLanguage {
  english,
  hinglish,
  hindi,
  punjabi,
}

extension _ReplyLanguageLabel on _ReplyLanguage {
  String get label {
    switch (this) {
      case _ReplyLanguage.english:
        return 'English';
      case _ReplyLanguage.hinglish:
        return 'Hinglish';
      case _ReplyLanguage.hindi:
        return 'Hindi';
      case _ReplyLanguage.punjabi:
        return 'Punjabi';
    }
  }
}
