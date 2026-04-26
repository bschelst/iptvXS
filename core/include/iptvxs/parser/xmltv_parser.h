// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#pragma once

#include <QObject>
#include <QVector>

#include "iptvxs/models/programme.h"

class QIODevice;

namespace iptvxs {

class XmltvParser : public QObject {
    Q_OBJECT

public:
    explicit XmltvParser(QObject *parent = nullptr);

    QVector<Programme> parse(QIODevice *device);
    QVector<Programme> parse(const QByteArray &data);

signals:
    void progressChanged(int current, int total);
    void errorOccurred(const QString &message);

private:
    static int64_t parseDateTime(const QString &dtStr);
};

} // namespace iptvxs
