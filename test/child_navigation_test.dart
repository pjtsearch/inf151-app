// Use FlutterFire's platform test APIs without runtime dependencies.
// ignore_for_file: depend_on_referenced_packages

import 'dart:async';

import 'package:cloud_firestore_platform_interface/src/pigeon/messages.pigeon.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inf151_app/app.dart';

class _Auth extends FirebaseAuthPlatform {
  UserPlatform? user;
  int signOuts = 0;
  late final StreamController<UserPlatform?> changes =
      StreamController<UserPlatform?>.broadcast(
        onListen: () => changes.add(user),
      );

  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseAuthPlatform setInitialValues({
    InternalUserDetails? currentUser,
    String? languageCode,
  }) => this;

  @override
  UserPlatform? get currentUser => user;

  @override
  Stream<UserPlatform?> authStateChanges() => changes.stream;

  @override
  Future<UserCredentialPlatform> signInAnonymously() async {
    user = _User(this);
    changes.add(user);
    return _Credential(auth: this, user: user);
  }

  @override
  Future<void> signOut() async {
    signOuts++;
    user = null;
    changes.add(null);
  }
}

class _Credential extends UserCredentialPlatform {
  _Credential({required super.auth, super.user});
}

class _MultiFactor extends MultiFactorPlatform {
  _MultiFactor(super.auth);
}

class _User extends UserPlatform {
  _User(FirebaseAuthPlatform auth)
    : super(
        auth,
        _MultiFactor(auth),
        InternalUserDetails(
          userInfo: InternalUserInfo(
            uid: 'child-session',
            isAnonymous: true,
            isEmailVerified: false,
          ),
          providerData: [],
        ),
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final auth = _Auth();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    FirebaseAuthPlatform.instance = auth;
  });

  setUp(() {
    auth.user = null;
    auth.signOuts = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(
          BasicMessageChannel<Object?>(
            'dev.flutter.pigeon.cloud_firestore_platform_interface.FirebaseFirestoreHostApi.documentReferenceGet',
            PigeonCodec(),
          ),
          (message) async => [
            InternalDocumentSnapshot(
              path: 'parents/child-session',
              data: null,
              metadata: InternalSnapshotMetadata(
                hasPendingWrites: false,
                isFromCache: false,
              ),
            ),
          ],
        );
  });

  tearDownAll(() => auth.changes.close());

  for (final systemBack in [false, true]) {
    testWidgets(
      '${systemBack ? 'system' : 'app bar'} back returns child entry to welcome',
      (tester) async {
        await tester.pumpWidget(const GoalApp());
        await tester.pumpAndSettle();
        await tester.tap(find.text('I’m a child'));
        await tester.pumpAndSettle();
        expect(find.text('Connect to your goals'), findsOneWidget);

        if (systemBack) {
          await tester.binding.handlePopRoute();
        } else {
          await tester.tap(find.byType(BackButton));
        }
        await tester.pumpAndSettle();

        expect(find.text('Welcome to GoalPunch'), findsOneWidget);
        expect(find.text('I’m a parent'), findsOneWidget);
        expect(find.text('I’m a child'), findsOneWidget);
        expect(auth.currentUser, isNull);
        expect(auth.signOuts, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
