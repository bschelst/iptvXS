#pragma once

#include <QObject>
#include <QSqlDatabase>
#include <QString>
#include <functional>
#include <vector>

namespace iptvxs {

class Database : public QObject {
    Q_OBJECT

public:
    explicit Database(QObject *parent = nullptr);
    ~Database() override;

    bool open(const QString &path);
    void close();
    bool isOpen() const;

    QSqlDatabase connection() const;

signals:
    void migrationApplied(int version);
    void errorOccurred(const QString &message);

private:
    struct Migration {
        int version;
        QString description;
        std::function<bool(QSqlDatabase &)> apply;
    };

    bool applyMigrations();
    bool setPragmas();
    int currentSchemaVersion() const;
    std::vector<Migration> migrations() const;

    QSqlDatabase db_;
    QString connectionName_;
};

} // namespace iptvxs
