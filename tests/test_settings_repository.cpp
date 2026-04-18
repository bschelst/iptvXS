#include <QSqlDatabase>
#include <QTemporaryDir>
#include <QtTest>

#include "iptvxs/db/database.h"
#include "iptvxs/db/settings_repository.h"

class TestSettingsRepository : public QObject {
    Q_OBJECT

private slots:
    void initTestCase() {
        tmpDir_ = std::make_unique<QTemporaryDir>();
        QVERIFY(tmpDir_->isValid());

        db_ = std::make_unique<iptvxs::Database>();
        QVERIFY(db_->open(tmpDir_->filePath("test.db")));
    }

    void cleanupTestCase() {
        db_.reset();
        tmpDir_.reset();
    }

    void testSetAndGetString() {
        iptvxs::SettingsRepository repo(db_->connection());
        repo.set(QStringLiteral("test_key"), QStringLiteral("test_value"));
        QCOMPARE(repo.getString("test_key"), "test_value");
    }

    void testGetStringDefault() {
        iptvxs::SettingsRepository repo(db_->connection());
        QCOMPARE(repo.getString("nonexistent", "fallback"), "fallback");
    }

    void testSetAndGetInt() {
        iptvxs::SettingsRepository repo(db_->connection());
        repo.set("int_key", 42);
        QCOMPARE(repo.getInt("int_key"), 42);
    }

    void testSetAndGetBool() {
        iptvxs::SettingsRepository repo(db_->connection());
        repo.set("bool_true", true);
        repo.set("bool_false", false);
        QCOMPARE(repo.getBool("bool_true"), true);
        QCOMPARE(repo.getBool("bool_false"), false);
    }

    void testSetAndGetDouble() {
        iptvxs::SettingsRepository repo(db_->connection());
        repo.set("pi", 3.14159265358979);
        QCOMPARE(repo.getDouble("pi"), 3.14159265358979);
    }

    void testOverwrite() {
        iptvxs::SettingsRepository repo(db_->connection());
        repo.set(QStringLiteral("key"), QStringLiteral("first"));
        repo.set(QStringLiteral("key"), QStringLiteral("second"));
        QCOMPARE(repo.getString("key"), "second");
    }

    void testRemove() {
        iptvxs::SettingsRepository repo(db_->connection());
        repo.set(QStringLiteral("removable"), QStringLiteral("value"));
        QVERIFY(repo.contains("removable"));
        repo.remove("removable");
        QVERIFY(!repo.contains("removable"));
    }

    void testContains() {
        iptvxs::SettingsRepository repo(db_->connection());
        QVERIFY(!repo.contains("ghost"));
        repo.set(QStringLiteral("ghost"), QStringLiteral("boo"));
        QVERIFY(repo.contains("ghost"));
    }

private:
    std::unique_ptr<QTemporaryDir> tmpDir_;
    std::unique_ptr<iptvxs::Database> db_;
};

QTEST_MAIN(TestSettingsRepository)
#include "test_settings_repository.moc"
