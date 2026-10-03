import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A full-screen reader for the Terms / Privacy text. Shared by the sign-up
/// checkbox (so the patient can read what they're agreeing to) and Profile.
class LegalPage extends StatelessWidget {
  final String title;
  final String body;
  const LegalPage({super.key, required this.title, required this.body});

  static void open(BuildContext context, String title, String body) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => LegalPage(title: title, body: body)));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Text(body, style: TextStyle(fontSize: 14.5, color: c.ink, height: 1.6)),
        ),
      ),
    );
  }
}

// Placeholder copy — replace with the clinic's reviewed legal text before
// release. Kept short and generic rather than inventing specific data
// handling or retention claims.
const termsText = '''
These Terms & Conditions govern your use of the Inteli Rehab app. By using '''
    '''the app you agree to follow your prescribed rehabilitation plan as '''
    '''directed by your physiotherapist, and to use the wearable device and '''
    '''app as intended for home-based rehabilitation tracking.

This app supports, but does not replace, guidance from your clinic. Always '''
    '''follow your physiotherapist's instructions and contact your clinic '''
    '''with any concerns about your treatment.

This is placeholder text pending review by the clinic's legal team.
''';

const privacyText = '''
This Privacy Notice describes how Inteli Rehab handles your information. '''
    '''We collect the personal, injury and session data you and your '''
    '''wearable device provide in order to support your rehabilitation and '''
    '''share your progress with your clinic and physiotherapist.

Your data is only shared with the clinic and physiotherapist you choose. '''
    '''You can review the personal details you've provided at any time from '''
    '''this Profile screen.

This is placeholder text pending review by the clinic's legal team.
''';
