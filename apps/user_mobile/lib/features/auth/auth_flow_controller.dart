import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/auth_service.dart';

enum AuthBannerType { success, error }

typedef AuthAction = Future<AuthResult> Function();

class AuthBanner {
  const AuthBanner(this.message, this.type);

  final String message;
  final AuthBannerType type;
}

@immutable
class AuthFlowState {
  const AuthFlowState({
    this.isProcessing = false,
    this.banner,
  });

  final bool isProcessing;
  final AuthBanner? banner;

  AuthFlowState copyWith({
    bool? isProcessing,
    AuthBanner? banner,
  }) {
    return AuthFlowState(
      isProcessing: isProcessing ?? this.isProcessing,
      banner: banner,
    );
  }
}

class AuthFlowController extends StateNotifier<AuthFlowState> {
  AuthFlowController(this._authService) : super(const AuthFlowState());

  final AuthService _authService;

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _runAction(() => _authService.signInWithEmailAndPassword(email, password));
  }

  Future<void> register({
    required String email,
    required String password,
    required String name,
    required String phone,
  }) async {
    await _runAction(
      () => _authService.signUpWithEmailAndPassword(email, password, name, phone),
    );
  }

  Future<void> signInWithGoogle() async {
    await _runAction(_authService.signInWithGoogle);
  }

  Future<void> sendPasswordReset(String email) async {
    if (email.trim().isEmpty) {
      state = state.copyWith(
        banner: const AuthBanner('Enter your email to reset your password.', AuthBannerType.error),
      );
      return;
    }
    await _runAction(() => _authService.sendPasswordReset(email.trim()));
  }

  void clearBanner() {
    if (state.banner != null) {
      state = state.copyWith(isProcessing: state.isProcessing, banner: null);
    }
  }

  void reset() {
    state = const AuthFlowState();
  }

  Future<void> _runAction(AuthAction action) async {
    state = state.copyWith(isProcessing: true, banner: null);
    final result = await action();
    state = state.copyWith(
      isProcessing: false,
      banner: result.success
          ? (result.message == null
              ? null
              : AuthBanner(result.message!, AuthBannerType.success))
          : AuthBanner(result.message ?? 'Something went wrong.', AuthBannerType.error),
    );
  }
}

final authServiceProvider = ChangeNotifierProvider<AuthService>((ref) {
  throw UnimplementedError('AuthService must be provided at runtime.');
});

final authFlowControllerProvider = StateNotifierProvider<AuthFlowController, AuthFlowState>((ref) {
  final service = ref.watch(authServiceProvider);
  return AuthFlowController(service);
});
