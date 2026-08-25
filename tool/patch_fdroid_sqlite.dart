import 'dart:io';

/// Patches pubspec.yaml to compile SQLite from source instead of downloading
/// a prebuilt binary. Used by the F-Droid build where binary downloads are
/// not allowed.
///
/// Also creates stub OpenSSL headers so the SQLCipher amalgamation compiles
/// when cross-compiling for Android (the NDK can't use host /usr/include).
void main(List<String> args) {
  final sqlcipherPath =
      args.isNotEmpty ? args[0] : Platform.environment['SQLCIPHER_PATH'] ?? '';

  if (sqlcipherPath.isEmpty) {
    stderr.writeln(
      'Usage: dart run tool/patch_fdroid_sqlite.dart <sqlcipher-path>',
    );
    exit(1);
  }

  final pubspec = File('pubspec.yaml');
  if (!pubspec.existsSync()) {
    stderr.writeln('pubspec.yaml not found');
    exit(1);
  }

  var content = pubspec.readAsStringSync();

  // Replace source: sqlcipher with source: source + path + defines
  final old = '      source: sqlcipher';
  final newPath = '$sqlcipherPath/sqlite3.c';
  final newContent = '''      source: source
      path: $newPath
      defines:
        - SQLITE_HAS_CODEC''';

  if (!content.contains(old)) {
    stderr.writeln('Could not find "$old" in pubspec.yaml');
    exit(1);
  }

  content = content.replaceFirst(old, newContent);
  pubspec.writeAsStringSync(content);

  // Create stub OpenSSL headers so the amalgamation compiles with the
  // Android NDK cross-compiler (which can't use host /usr/include).
  _createStubHeaders(sqlcipherPath);

  stdout.writeln(
    'Patched pubspec.yaml: sqlite3 source → source (from $newPath)',
  );
}

/// The SQLCipher amalgamation includes OpenSSL headers unconditionally
/// even with --with-crypto-lib=none. The NDK cross-compiler can't use
/// host /usr/include, so we provide minimal stub declarations.
void _createStubHeaders(String sqlcipherPath) {
  final opensslDir = Directory('$sqlcipherPath/openssl');
  opensslDir.createSync(recursive: true);

  File('${opensslDir.path}/crypto.h').writeAsStringSync('''
#ifndef OPENSSL_CRYPTO_H
#define OPENSSL_CRYPTO_H
typedef struct evp_cipher_ctx_st EVP_CIPHER_CTX;
typedef struct evp_md_ctx_st EVP_MD_CTX;
typedef struct evp_md_st EVP_MD;
typedef struct evp_cipher_st EVP_CIPHER;
typedef struct engine_st ENGINE;
typedef struct hmac_ctx_st HMAC_CTX;
int RAND_bytes(unsigned char *buf, int num);
#define OPENSSL_VERSION_NUMBER 0x10100000L
#endif
''');

  File('${opensslDir.path}/evp.h').writeAsStringSync('''
#ifndef OPENSSL_EVP_H
#define OPENSSL_EVP_H
#include <openssl/crypto.h>
const EVP_CIPHER *EVP_aes_256_cbc(void);
const EVP_CIPHER *EVP_aes_128_cbc(void);
const EVP_CIPHER *EVP_aes_256_ecb(void);
const EVP_MD *EVP_sha256(void);
const EVP_MD *EVP_sha512(void);
int EVP_CipherInit_ex(EVP_CIPHER_CTX *ctx, const EVP_CIPHER *cipher,
    ENGINE *impl, const unsigned char *key, const unsigned char *iv, int enc);
int EVP_CipherUpdate(EVP_CIPHER_CTX *ctx, unsigned char *out, int *outl,
    const unsigned char *in, int inl);
int EVP_CipherFinal_ex(EVP_CIPHER_CTX *ctx, unsigned char *out, int *outl);
EVP_MD_CTX *EVP_MD_CTX_new(void);
void EVP_MD_CTX_free(EVP_MD_CTX *ctx);
int EVP_DigestInit_ex(EVP_MD_CTX *ctx, const EVP_MD *type, ENGINE *impl);
int EVP_DigestUpdate(EVP_MD_CTX *ctx, const void *d, size_t cnt);
int EVP_DigestFinal_ex(EVP_MD_CTX *ctx, unsigned char *md, unsigned int *s);
#endif
''');

  File('${opensslDir.path}/hmac.h').writeAsStringSync('''
#ifndef OPENSSL_HMAC_H
#define OPENSSL_HMAC_H
#include <openssl/crypto.h>
HMAC_CTX *HMAC_CTX_new(void);
void HMAC_CTX_free(HMAC_CTX *ctx);
int HMAC_Init_ex(HMAC_CTX *ctx, const void *key, int key_len,
    const EVP_MD *md, ENGINE *impl);
int HMAC_Update(HMAC_CTX *ctx, const unsigned char *data, size_t len);
int HMAC_Final(HMAC_CTX *ctx, unsigned char *md, unsigned int *len);
#endif
''');

  File('${opensslDir.path}/opensslv.h').writeAsStringSync('''
#ifndef OPENSSL_OPENSSLV_H
#define OPENSSL_OPENSSLV_H
#define OPENSSL_VERSION_NUMBER 0x10100000L
#endif
''');

  File('${opensslDir.path}/rand.h').writeAsStringSync('''
#ifndef OPENSSL_RAND_H
#define OPENSSL_RAND_H
int RAND_bytes(unsigned char *buf, int num);
#endif
''');

  File('${opensslDir.path}/err.h').writeAsStringSync('''
#ifndef OPENSSL_ERR_H
#define OPENSSL_ERR_H
unsigned long ERR_get_error(void);
void ERR_clear_error(void);
#endif
''');

  File('${opensslDir.path}/objects.h').writeAsStringSync('''
#ifndef OPENSSL_OBJECTS_H
#define OPENSSL_OBJECTS_H
#endif
''');

  stdout.writeln('Created stub OpenSSL headers in ${opensslDir.path}');
}
