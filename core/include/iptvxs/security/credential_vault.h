// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#pragma once

#include <QString>
#include <QByteArray>

namespace iptvxs {

class CredentialVault {
public:
    CredentialVault();
    explicit CredentialVault(const QByteArray &testMasterKey);

    bool isReady() const;

    QString encrypt(const QString &plaintext, const QString &purpose) const;
    QString decrypt(const QString &encoded, const QString &purpose) const;

    bool isEncryptedValue(const QString &value) const;

private:
    bool loadOrCreateMasterKey();
    bool loadMasterKey();
    bool createMasterKey();
    bool storeMasterKey(const QByteArray &masterKey);

    QString encryptWithKey(const QString &plaintext, const QString &purpose) const;
    QString decryptWithKey(const QString &encoded, const QString &purpose) const;

    QByteArray masterKey_;
    bool ready_{false};
    bool testKeyMode_{false};
};

} // namespace iptvxs
