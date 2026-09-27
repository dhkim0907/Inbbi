import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as google_web;

Widget buildGoogleSignInButton() => google_web.renderButton(
  configuration: google_web.GSIButtonConfiguration(
    size: google_web.GSIButtonSize.medium,
    text: google_web.GSIButtonText.signinWith,
    minimumWidth: 200,
  ),
);
