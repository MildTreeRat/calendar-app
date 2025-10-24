import 'package:supabase_flutter/supabase_flutter.dart';
import '../logging/logger.dart';

// ============================================================================
// SupabaseService - Manages authentication and cloud connection
// ============================================================================

class SupabaseService {
  static SupabaseService? _instance;
  static SupabaseService get instance => _instance ?? (throw StateError('SupabaseService not initialized'));

  final SupabaseClient _client;
  final Logger _logger;

  SupabaseService._({
    required SupabaseClient client,
    required Logger logger,
  })  : _client = client,
        _logger = logger;

  /// Initialize Supabase with your project credentials
  static Future<SupabaseService> initialize({
    required String supabaseUrl,
    required String supabaseAnonKey,
  }) async {
    if (_instance != null) {
      return _instance!;
    }

    final logger = Logger.instance;

    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
        debug: false, // Set to true for development
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
      );

      _instance = SupabaseService._(
        client: Supabase.instance.client,
        logger: logger,
      );

      logger.info('Supabase initialized', tag: 'Supabase', metadata: {
        'url': supabaseUrl,
      });

      // Listen to auth state changes
      _instance!._setupAuthListener();

      return _instance!;
    } catch (e, stack) {
      logger.error('Failed to initialize Supabase',
        tag: 'Supabase',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  void _setupAuthListener() {
    _client.auth.onAuthStateChange.listen((event) {
      _logger.info('Auth state changed', tag: 'Supabase', metadata: {
        'event': event.event.name,
        'user_id': event.session?.user.id,
      });
    });
  }

  // ============================================================================
  // Authentication Methods
  // ============================================================================

  /// Sign in with email and password
  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) async {
    try {
      _logger.debug('Signing in', tag: 'Supabase', metadata: {'email': email});

      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        _logger.info('Sign in successful', tag: 'Supabase', metadata: {
          'user_id': response.user!.id,
          'email': response.user!.email,
        });
      }

      return response;
    } catch (e, stack) {
      _logger.error('Sign in failed',
        tag: 'Supabase',
        error: e,
        stackTrace: stack,
        metadata: {'email': email},
      );
      rethrow;
    }
  }

  /// Sign up with email and password
  Future<AuthResponse> signUpWithPassword({
    required String email,
    required String password,
    Map<String, dynamic>? data,
  }) async {
    try {
      _logger.debug('Signing up', tag: 'Supabase', metadata: {'email': email});

      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: data,
      );

      if (response.user != null) {
        _logger.info('Sign up successful', tag: 'Supabase', metadata: {
          'user_id': response.user!.id,
          'email': response.user!.email,
        });
      }

      return response;
    } catch (e, stack) {
      _logger.error('Sign up failed',
        tag: 'Supabase',
        error: e,
        stackTrace: stack,
        metadata: {'email': email},
      );
      rethrow;
    }
  }

  /// Sign out the current user
  Future<void> signOut() async {
    try {
      final userId = _client.auth.currentUser?.id;
      _logger.debug('Signing out', tag: 'Supabase', metadata: {'user_id': userId});

      await _client.auth.signOut();

      _logger.info('Sign out successful', tag: 'Supabase', metadata: {
        'user_id': userId,
      });
    } catch (e, stack) {
      _logger.error('Sign out failed',
        tag: 'Supabase',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  /// Send password reset email
  Future<void> resetPassword({required String email}) async {
    try {
      _logger.debug('Sending password reset', tag: 'Supabase', metadata: {'email': email});

      await _client.auth.resetPasswordForEmail(email);

      _logger.info('Password reset email sent', tag: 'Supabase', metadata: {
        'email': email,
      });
    } catch (e, stack) {
      _logger.error('Password reset failed',
        tag: 'Supabase',
        error: e,
        stackTrace: stack,
        metadata: {'email': email},
      );
      rethrow;
    }
  }

  // ============================================================================
  // User Information
  // ============================================================================

  /// Get the current authenticated user
  User? get currentUser => _client.auth.currentUser;

  /// Get the current user's ID (null if not authenticated)
  String? get currentUserId => _client.auth.currentUser?.id;

  /// Check if a user is currently authenticated
  bool get isAuthenticated => _client.auth.currentUser != null;

  /// Get the current session
  Session? get currentSession => _client.auth.currentSession;

  // ============================================================================
  // Database Access
  // ============================================================================

  /// Get a reference to a Supabase table
  SupabaseQueryBuilder from(String table) {
    return _client.from(table);
  }

  /// Execute a raw RPC call
  Future<dynamic> rpc(String functionName, {Map<String, dynamic>? params}) async {
    try {
      _logger.debug('Calling RPC', tag: 'Supabase', metadata: {
        'function': functionName,
      });

      return await _client.rpc(functionName, params: params);
    } catch (e, stack) {
      _logger.error('RPC call failed',
        tag: 'Supabase',
        error: e,
        stackTrace: stack,
        metadata: {'function': functionName},
      );
      rethrow;
    }
  }

  // ============================================================================
  // Helpers
  // ============================================================================

  /// Get the Supabase client for advanced operations
  SupabaseClient get client => _client;
}
