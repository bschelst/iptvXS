// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#include "iptvxs/security/credential_vault.h"

#include <QByteArray>
#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QRandomGenerator>
#include <QSaveFile>
#include <QStandardPaths>
#include <QStringConverter>

#include <openssl/evp.h>
#include <openssl/rand.h>

#if defined(Q_OS_WIN)
#  include <windows.h>
#  include <wincrypt.h>
#elif defined(Q_OS_UNIX)
#  ifdef signals
#    undef signals
#  endif
#  ifdef slots
#    undef slots
#  endif
#  include <libsecret/secret.h>
#endif

namespace iptvxs {

namespace {

constexpr auto kPrefix = "enc:v1:";
constexpr int kKeySize = 32;
constexpr int kNonceSize = 12;
constexpr int kTagSize = 16;

QByteArray protectedKeyFilePath() {
    auto dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    return QDir(dir).filePath(QStringLiteral("credential-key.bin")).toUtf8();
}

QByteArray randomBytes(int size) {
    QByteArray out(size, Qt::Uninitialized);
    if (RAND_bytes(reinterpret_cast<unsigned char *>(out.data()), size) != 1) {
        return {};
    }
    return out;
}

bool aesGcmEncrypt(const QByteArray &key, const QByteArray &nonce,
                   const QByteArray &aad, const QByteArray &plaintext,
                   QByteArray *ciphertext, QByteArray *tag) {
    if (key.size() != kKeySize || nonce.size() != kNonceSize) return false;
    auto *ctx = EVP_CIPHER_CTX_new();
    if (!ctx) return false;

    bool ok = false;
    do {
        int outLen = 0;
        if (EVP_EncryptInit_ex(ctx, EVP_aes_256_gcm(), nullptr, nullptr, nullptr) != 1) break;
        if (EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_IVLEN, nonce.size(), nullptr) != 1) break;
        if (EVP_EncryptInit_ex(ctx, nullptr, nullptr,
                               reinterpret_cast<const unsigned char *>(key.constData()),
                               reinterpret_cast<const unsigned char *>(nonce.constData())) != 1) {
            break;
        }
        if (!aad.isEmpty()) {
            if (EVP_EncryptUpdate(ctx, nullptr, &outLen,
                                  reinterpret_cast<const unsigned char *>(aad.constData()),
                                  aad.size()) != 1) {
                break;
            }
        }
        ciphertext->resize(plaintext.size() + EVP_CIPHER_block_size(EVP_aes_256_gcm()));
        if (EVP_EncryptUpdate(ctx,
                              reinterpret_cast<unsigned char *>(ciphertext->data()), &outLen,
                              reinterpret_cast<const unsigned char *>(plaintext.constData()),
                              plaintext.size()) != 1) {
            break;
        }
        int total = outLen;
        if (EVP_EncryptFinal_ex(ctx,
                                reinterpret_cast<unsigned char *>(ciphertext->data()) + total,
                                &outLen) != 1) {
            break;
        }
        total += outLen;
        ciphertext->resize(total);
        tag->resize(kTagSize);
        if (EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_GET_TAG, tag->size(),
                                reinterpret_cast<unsigned char *>(tag->data())) != 1) {
            break;
        }
        ok = true;
    } while (false);

    EVP_CIPHER_CTX_free(ctx);
    return ok;
}

bool aesGcmDecrypt(const QByteArray &key, const QByteArray &nonce,
                   const QByteArray &aad, const QByteArray &ciphertext,
                   const QByteArray &tag, QByteArray *plaintext) {
    if (key.size() != kKeySize || nonce.size() != kNonceSize || tag.size() != kTagSize) {
        return false;
    }
    auto *ctx = EVP_CIPHER_CTX_new();
    if (!ctx) return false;

    bool ok = false;
    do {
        int outLen = 0;
        if (EVP_DecryptInit_ex(ctx, EVP_aes_256_gcm(), nullptr, nullptr, nullptr) != 1) break;
        if (EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_IVLEN, nonce.size(), nullptr) != 1) break;
        if (EVP_DecryptInit_ex(ctx, nullptr, nullptr,
                               reinterpret_cast<const unsigned char *>(key.constData()),
                               reinterpret_cast<const unsigned char *>(nonce.constData())) != 1) {
            break;
        }
        if (!aad.isEmpty()) {
            if (EVP_DecryptUpdate(ctx, nullptr, &outLen,
                                  reinterpret_cast<const unsigned char *>(aad.constData()),
                                  aad.size()) != 1) {
                break;
            }
        }
        plaintext->resize(ciphertext.size());
        if (EVP_DecryptUpdate(ctx,
                              reinterpret_cast<unsigned char *>(plaintext->data()), &outLen,
                              reinterpret_cast<const unsigned char *>(ciphertext.constData()),
                              ciphertext.size()) != 1) {
            break;
        }
        int total = outLen;
        if (EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_TAG, tag.size(),
                                const_cast<unsigned char *>(
                                    reinterpret_cast<const unsigned char *>(tag.constData()))) != 1) {
            break;
        }
        if (EVP_DecryptFinal_ex(ctx,
                                reinterpret_cast<unsigned char *>(plaintext->data()) + total,
                                &outLen) != 1) {
            break;
        }
        total += outLen;
        plaintext->resize(total);
        ok = true;
    } while (false);

    EVP_CIPHER_CTX_free(ctx);
    return ok;
}

} // namespace

CredentialVault::CredentialVault() {
    ready_ = loadOrCreateMasterKey();
}

CredentialVault::CredentialVault(const QByteArray &testMasterKey)
    : masterKey_(testMasterKey), ready_(testMasterKey.size() == kKeySize), testKeyMode_(true) {}

bool CredentialVault::isReady() const { return ready_ && masterKey_.size() == kKeySize; }

bool CredentialVault::isEncryptedValue(const QString &value) const {
    return value.startsWith(QLatin1String(kPrefix));
}

QString CredentialVault::encrypt(const QString &plaintext, const QString &purpose) const {
    if (plaintext.isEmpty()) return {};
    return encryptWithKey(plaintext, purpose);
}

QString CredentialVault::decrypt(const QString &encoded, const QString &purpose) const {
    if (encoded.isEmpty()) return {};
    if (!isEncryptedValue(encoded)) return encoded;
    return decryptWithKey(encoded, purpose);
}

bool CredentialVault::loadOrCreateMasterKey() {
    if (loadMasterKey()) return true;
    return createMasterKey();
}

bool CredentialVault::loadMasterKey() {
    if (testKeyMode_) return isReady();
#if defined(Q_OS_WIN)
    const auto path = QString::fromUtf8(protectedKeyFilePath());
    QFile file(path);
    if (!file.exists() || !file.open(QIODevice::ReadOnly)) {
        return false;
    }
    const auto protectedBlob = file.readAll();
    file.close();
    if (protectedBlob.isEmpty()) return false;

    DATA_BLOB in{};
    in.pbData = reinterpret_cast<BYTE *>(const_cast<char *>(protectedBlob.constData()));
    in.cbData = static_cast<DWORD>(protectedBlob.size());
    DATA_BLOB out{};
    if (!CryptUnprotectData(&in, nullptr, nullptr, nullptr, nullptr, 0, &out)) {
        return false;
    }
    QByteArray raw(reinterpret_cast<const char *>(out.pbData), static_cast<int>(out.cbData));
    LocalFree(out.pbData);
    if (raw.size() != kKeySize) return false;
    masterKey_ = raw;
    return true;
#elif defined(Q_OS_UNIX)
    static const SecretSchema schema = {
        "org.schelstraete.iptvxs.masterkey",
        SECRET_SCHEMA_NONE,
        {
            {"app", SECRET_SCHEMA_ATTRIBUTE_STRING},
            {"purpose", SECRET_SCHEMA_ATTRIBUTE_STRING},
            {nullptr, static_cast<SecretSchemaAttributeType>(0)},
        }
    };
    GError *error = nullptr;
    gchar *secret = secret_password_lookup_sync(&schema, nullptr, &error,
                                                "app", "iptvXS",
                                                "purpose", "masterkey",
                                                nullptr);
    if (!secret) {
        if (error) g_error_free(error);
        return false;
    }
    QByteArray raw = QByteArray::fromBase64(QByteArray(secret));
    secret_password_free(secret);
    if (raw.size() != kKeySize) return false;
    masterKey_ = raw;
    return true;
#else
    return false;
#endif
}

bool CredentialVault::createMasterKey() {
    if (testKeyMode_) return isReady();
    auto key = randomBytes(kKeySize);
    if (key.size() != kKeySize) return false;
    if (!storeMasterKey(key)) return false;
    masterKey_ = key;
    return true;
}

bool CredentialVault::storeMasterKey(const QByteArray &masterKey) {
    if (testKeyMode_) return isReady();
#if defined(Q_OS_WIN)
    DATA_BLOB in{};
    in.pbData = reinterpret_cast<BYTE *>(const_cast<char *>(masterKey.constData()));
    in.cbData = static_cast<DWORD>(masterKey.size());
    DATA_BLOB out{};
    if (!CryptProtectData(&in, L"iptvXS master key", nullptr, nullptr, nullptr, 0, &out)) {
        return false;
    }
    QByteArray protectedBlob(reinterpret_cast<const char *>(out.pbData), static_cast<int>(out.cbData));
    LocalFree(out.pbData);
    QDir().mkpath(QFileInfo(QString::fromUtf8(protectedKeyFilePath())).absolutePath());
    QSaveFile file(QString::fromUtf8(protectedKeyFilePath()));
    if (!file.open(QIODevice::WriteOnly)) {
        return false;
    }
    if (file.write(protectedBlob) != protectedBlob.size()) {
        return false;
    }
    return file.commit();
#elif defined(Q_OS_UNIX)
    static const SecretSchema schema = {
        "org.schelstraete.iptvxs.masterkey",
        SECRET_SCHEMA_NONE,
        {
            {"app", SECRET_SCHEMA_ATTRIBUTE_STRING},
            {"purpose", SECRET_SCHEMA_ATTRIBUTE_STRING},
            {nullptr, static_cast<SecretSchemaAttributeType>(0)},
        }
    };
    const auto encoded = masterKey.toBase64();
    GError *error = nullptr;
    gboolean ok = secret_password_store_sync(&schema, SECRET_COLLECTION_DEFAULT,
                                             "iptvXS master key", encoded.constData(),
                                             nullptr, &error,
                                             "app", "iptvXS",
                                             "purpose", "masterkey",
                                             nullptr);
    if (!ok) {
        if (error) g_error_free(error);
        return false;
    }
    return true;
#else
    return false;
#endif
}

QString CredentialVault::encryptWithKey(const QString &plaintext, const QString &purpose) const {
    if (!isReady()) return {};
    auto iv = randomBytes(kNonceSize);
    if (iv.size() != kNonceSize) return {};

    QByteArray cipher;
    QByteArray tag;
    const auto aad = purpose.toUtf8();
    const auto plain = plaintext.toUtf8();
    if (!aesGcmEncrypt(masterKey_, iv, aad, plain, &cipher, &tag)) {
        return {};
    }
    QByteArray packed;
    packed.reserve(iv.size() + tag.size() + cipher.size());
    packed.append(iv);
    packed.append(tag);
    packed.append(cipher);
    return QString::fromLatin1(kPrefix) +
           QString::fromLatin1(packed.toBase64(QByteArray::Base64UrlEncoding |
                                               QByteArray::OmitTrailingEquals));
}

QString CredentialVault::decryptWithKey(const QString &encoded, const QString &purpose) const {
    if (!isReady()) return {};
    const auto payload = encoded.mid(QString::fromLatin1(kPrefix).size()).toLatin1();
    const auto packed = QByteArray::fromBase64(payload, QByteArray::Base64UrlEncoding);
    if (packed.size() <= kNonceSize + kTagSize) return {};

    const auto iv = packed.left(kNonceSize);
    const auto tag = packed.mid(kNonceSize, kTagSize);
    const auto cipher = packed.mid(kNonceSize + kTagSize);
    QByteArray plain;
    if (!aesGcmDecrypt(masterKey_, iv, purpose.toUtf8(), cipher, tag, &plain)) {
        return {};
    }
    return QString::fromUtf8(plain);
}

} // namespace iptvxs
