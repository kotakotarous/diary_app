import 'package:googleapis/calendar/v3.dart' as gcal;
import 'google_auth_desktop.dart' if (dart.library.html) 'google_auth_web.dart';
import 'google_auth_interface.dart';

export 'google_auth_interface.dart';

class GoogleCalendarEvent {
  final String id;
  final String title;
  final DateTime start;
  final DateTime? end;
  final String? description;
  final String? location;
  final bool isAllDay;

  GoogleCalendarEvent({
    required this.id,
    required this.title,
    required this.start,
    this.end,
    this.description,
    this.location,
    this.isAllDay = false,
  });
}

class GoogleCalendarService {
  static final instance = GoogleCalendarService._();
  GoogleCalendarService._();

  final GoogleAuthInterface _auth = GoogleAuthImpl.instance;

  bool get hasClientId => _auth.hasClientId;
  bool get isLoggedIn  => _auth.isLoggedIn;
  String? get userEmail => _auth.userEmail;
  String? get userName  => _auth.userName;
  String? get callbackError => _auth.callbackError;

  Future<bool> loadSaved() => _auth.loadSaved();
  Future<void> saveClientId(String id, [String? secret]) =>
      _auth.saveClientId(id, secret);
  Future<void> signIn()  => _auth.signIn();
  Future<void> signOut() => _auth.signOut();

  Future<List<GoogleCalendarEvent>> fetchEvents(
      {DateTime? from, DateTime? to}) async {
    return _auth.withClient((client) async {
      final api = gcal.CalendarApi(client);
      final now = DateTime.now();
      final result = await api.events.list(
        'primary',
        timeMin: (from ?? now.subtract(const Duration(days: 90))).toUtc(),
        timeMax: (to ?? now.add(const Duration(days: 30))).toUtc(),
        singleEvents: true,
        orderBy: 'startTime',
        maxResults: 500,
      );
      return (result.items ?? []).map((e) {
        final isAllDay = e.start?.date != null;
        final start = isAllDay
            ? e.start!.date!
            : (e.start?.dateTime?.toLocal() ?? DateTime.now());
        final end = isAllDay
            ? e.end?.date
            : e.end?.dateTime?.toLocal();
        return GoogleCalendarEvent(
          id: e.id ?? '',
          title: e.summary ?? '（タイトルなし）',
          start: start,
          end: end,
          description: e.description,
          location: e.location,
          isAllDay: isAllDay,
        );
      }).toList();
    });
  }
}
