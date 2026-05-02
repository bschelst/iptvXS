// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#pragma once

#include <QAbstractListModel>
#include <QQmlEngine>
#include <QString>
#include <QVector>

class LogViewModel : public QAbstractListModel {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(QString filterLevel READ filterLevel WRITE setFilterLevel NOTIFY filterLevelChanged)

public:
    enum Roles {
        LevelRole = Qt::UserRole + 1,
        TimestampRole,
        MessageRole,
        ColorRole
    };

    explicit LogViewModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    int count() const;
    QString filterLevel() const;
    void setFilterLevel(const QString &level);

    Q_INVOKABLE void clear();
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void appendLog(const QString &level, const QString &timestamp,
                               const QString &message);

signals:
    void countChanged();
    void filterLevelChanged();
    void newLogEntry();

private:
    struct LogEntry {
        QString level;
        QString timestamp;
        QString message;
    };

    void rebuildFiltered();
    void rebuildFilteredNoReset();
    static QString colorForLevel(const QString &level);

    QVector<LogEntry> allEntries_;
    QVector<int> filteredIndices_;
    QString filterLevel_{QStringLiteral("WARN")};

    static constexpr int kMaxEntries = 5000;
};
