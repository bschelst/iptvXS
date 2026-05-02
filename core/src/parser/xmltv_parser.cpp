// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#include "iptvxs/parser/xmltv_parser.h"

#include <QBuffer>
#include <QDateTime>
#include <QTimeZone>
#include <QXmlStreamReader>

namespace iptvxs {

XmltvParser::XmltvParser(QObject *parent) : QObject(parent) {}

QVector<Programme> XmltvParser::parse(QIODevice *device) {
    QVector<Programme> programmes;

    if (!device || !device->isOpen()) {
        emit errorOccurred("XMLTV device is not open");
        return programmes;
    }

    QXmlStreamReader xml(device);

    while (!xml.atEnd() && !xml.hasError()) {
        auto token = xml.readNext();

        if (token != QXmlStreamReader::StartElement) {
            continue;
        }

        if (xml.name() != u"programme") {
            continue;
        }

        auto attrs = xml.attributes();
        QString channelId = attrs.value("channel").toString();
        QString startStr = attrs.value("start").toString();
        QString stopStr = attrs.value("stop").toString();

        if (channelId.isEmpty() || startStr.isEmpty()) {
            continue;
        }

        Programme prog;
        prog.epgChannelId = channelId.trimmed().toLower();
        prog.startTime = parseDateTime(startStr);
        prog.endTime = parseDateTime(stopStr);

        if (prog.startTime == 0) {
            continue;
        }

        while (!(xml.readNext() == QXmlStreamReader::EndElement &&
                 xml.name() == u"programme")) {
            if (xml.tokenType() != QXmlStreamReader::StartElement) {
                continue;
            }

            if (xml.name() == u"title") {
                prog.title = xml.readElementText();
            } else if (xml.name() == u"desc") {
                prog.description = xml.readElementText();
            }
        }

        if (!prog.title.isEmpty()) {
            programmes.append(prog);
        }
    }

    if (xml.hasError()) {
        emit errorOccurred(
            QStringLiteral("XMLTV parse error: %1").arg(xml.errorString()));
    }

    return programmes;
}

QVector<Programme> XmltvParser::parse(const QByteArray &data) {
    QBuffer buffer;
    buffer.setData(data);
    buffer.open(QIODevice::ReadOnly);
    return parse(&buffer);
}

int64_t XmltvParser::parseDateTime(const QString &dtStr) {
    if (dtStr.isEmpty()) {
        return 0;
    }

    // XMLTV format: "YYYYMMDDHHmmss +ZZZZ" or "YYYYMMDDHHmmss"
    QString cleaned = dtStr.trimmed();
    QString datePart = cleaned.left(14);
    QString tzPart;

    if (cleaned.length() > 14) {
        tzPart = cleaned.mid(14).trimmed();
    }

    QDateTime dt = QDateTime::fromString(datePart, "yyyyMMddHHmmss");

    if (!dt.isValid()) {
        return 0;
    }

    if (!tzPart.isEmpty()) {
        bool ok = false;
        int tzOffsetHours = tzPart.left(3).toInt(&ok);
        int tzOffsetMins = 0;
        if (ok && tzPart.length() >= 5) {
            tzOffsetMins = tzPart.mid(3, 2).toInt();
            if (tzOffsetHours < 0) {
                tzOffsetMins = -tzOffsetMins;
            }
        }
        int totalOffsetSecs = tzOffsetHours * 3600 + tzOffsetMins * 60;
        dt.setTimeZone(QTimeZone::fromSecondsAheadOfUtc(totalOffsetSecs));
    } else {
        dt.setTimeZone(QTimeZone::utc());
    }

    return dt.toSecsSinceEpoch();
}

} // namespace iptvxs
