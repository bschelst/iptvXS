#include <QtTest>

#include "iptvxs/security/credential_vault.h"

class TestCredentialVault : public QObject {
    Q_OBJECT

private slots:
    void testEncryptDecryptRoundTrip() {
        QByteArray key(32, '\x42');
        iptvxs::CredentialVault vault(key);

        const auto enc = vault.encrypt(QStringLiteral("user123"), QStringLiteral("username"));
        QVERIFY(!enc.isEmpty());
        QVERIFY(vault.isEncryptedValue(enc));
        QCOMPARE(vault.decrypt(enc, QStringLiteral("username")), QStringLiteral("user123"));
    }

    void testDecryptPlaintextPassthrough() {
        QByteArray key(32, '\x42');
        iptvxs::CredentialVault vault(key);
        QCOMPARE(vault.decrypt(QStringLiteral("plain-text"), QStringLiteral("username")),
                 QStringLiteral("plain-text"));
    }

    void testDifferentPurposeFailsToDecrypt() {
        QByteArray key(32, '\x42');
        iptvxs::CredentialVault vault(key);
        const auto enc = vault.encrypt(QStringLiteral("secret"), QStringLiteral("username"));
        QVERIFY(!enc.isEmpty());
        QCOMPARE(vault.decrypt(enc, QStringLiteral("password")), QString());
    }
};

QTEST_MAIN(TestCredentialVault)
#include "test_credential_vault.moc"
