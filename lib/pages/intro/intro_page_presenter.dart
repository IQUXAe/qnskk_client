// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';

import 'package:fluffychat/pages/intro/intro_page.dart';
import 'package:fluffychat/utils/localized_exception_extension.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/oidc_session_json_extension.dart';
import 'package:fluffychat/utils/qnskk_homeserver.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix_api_lite/utils/logs.dart';
import 'package:matrix/msc_extensions/msc_2964_oidc_login_flow/msc_2964_oidc_login_flow.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_html/universal_html.dart' as web;

class IntroPagePresenter extends StatefulWidget {
  const IntroPagePresenter({super.key});

  @override
  State<IntroPagePresenter> createState() => _IntroPagePresenterState();
}

class _IntroPagePresenterState extends State<IntroPagePresenter> {
  bool isLoading = kIsWeb;
  String? loggingInToHomeserver;

  @override
  void initState() {
    super.initState();

    if (kIsWeb) _finishOidcLogin();
  }

  Future<void> _finishOidcLogin() async {
    final store = await SharedPreferences.getInstance();
    final homeserverUrl = qnskkHomeserverUri();

    final oidcSessionString = store.getString(
      OidcSessionJsonExtension.storeKey,
    );
    final session = oidcSessionString == null
        ? null
        : OidcSessionJsonExtension.fromJson(jsonDecode(oidcSessionString));

    await store.remove(OidcSessionJsonExtension.storeKey);
    await store.remove(OidcSessionJsonExtension.homeserverStoreKey);
    if (!mounted) return;

    if (session == null) {
      setState(() {
        isLoading = false;
      });

      return;
    }
    setState(() {
      loggingInToHomeserver = homeserverUrl.origin;
    });

    try {
      final returnUrl = Uri.parse(web.window.location.href);
      final queryParameters = returnUrl.hasFragment
          ? Uri.parse(returnUrl.fragment).queryParameters
          : returnUrl.queryParameters;
      final code = queryParameters['code'] as String;
      final state = queryParameters['state'] as String;

      final client = await Matrix.of(context).getLoginClient();
      await client.checkHomeserver(homeserverUrl);
      await client.oidcLogin(session: session, code: code, state: state);
      if (!mounted) return;
      context.go('/backup');
    } catch (e, s) {
      Logs().w('Unable to login via OIDC', e, s);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toLocalizedString(context))));
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _openAuthForm(String route) async {
    setState(() {
      isLoading = true;
      loggingInToHomeserver = qnskkHomeserverUri().origin;
    });
    try {
      final client = await Matrix.of(context).getLoginClient();
      client.homeserver = qnskkHomeserverUri();
      if (!mounted) return;
      context.go('${GoRouterState.of(context).uri.path}/$route', extra: client);
    } catch (e, s) {
      Logs().w('Unable to open auth form', e, s);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toLocalizedString(context))));
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
          loggingInToHomeserver = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return IntroPage(
      isLoading: isLoading,
      loggingInToHomeserver: loggingInToHomeserver,
      login: () => _openAuthForm('login'),
      register: () => _openAuthForm('register'),
    );
  }
}
