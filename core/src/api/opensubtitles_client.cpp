// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#include "iptvxs/api/opensubtitles_client.h"

#include <QFile>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QProcess>
#include <QXmlStreamReader>
#include <QXmlStreamWriter>

#include "iptvxs/net/http_client.h"

namespace iptvxs {

static const QString kApiUrl =
    QStringLiteral("https://api.opensubtitles.org/xml-rpc");
static const QString kUserAgent = QStringLiteral("iptvXS v0.1.0");

static QByteArray buildXmlRpc(const QString &method,
                               std::function<void(QXmlStreamWriter &)> writeParams) {
    QByteArray data;
    QXmlStreamWriter xml(&data);
    xml.writeStartDocument();
    xml.writeStartElement(QStringLiteral("methodCall"));
    xml.writeTextElement(QStringLiteral("methodName"), method);
    xml.writeStartElement(QStringLiteral("params"));
    writeParams(xml);
    xml.writeEndElement(); // params
    xml.writeEndElement(); // methodCall
    xml.writeEndDocument();
    return data;
}

static void writeStringParam(QXmlStreamWriter &xml, const QString &val) {
    xml.writeStartElement(QStringLiteral("param"));
    xml.writeStartElement(QStringLiteral("value"));
    xml.writeTextElement(QStringLiteral("string"), val);
    xml.writeEndElement();
    xml.writeEndElement();
}

static QMap<QString, QString> parseStructMembers(QXmlStreamReader &xml) {
    QMap<QString, QString> members;
    while (!xml.atEnd()) {
        xml.readNext();
        if (xml.isStartElement() && xml.name() == QStringLiteral("member")) {
            QString name;
            QString value;
            while (!xml.atEnd()) {
                xml.readNext();
                if (xml.isStartElement() && xml.name() == QStringLiteral("name")) {
                    name = xml.readElementText();
                } else if (xml.isStartElement() &&
                         (xml.name() == QStringLiteral("string") ||
                          xml.name() == QStringLiteral("int") ||
                          xml.name() == QStringLiteral("double"))) {
                    value = xml.readElementText();
                } else if (xml.isStartElement() && xml.name() == QStringLiteral("value")) {
                    while (!xml.atEnd()) {
                        xml.readNext();
                        if (xml.isStartElement() &&
                            (xml.name() == QStringLiteral("string") ||
                             xml.name() == QStringLiteral("int") ||
                             xml.name() == QStringLiteral("double"))) {
                            value = xml.readElementText();
                        } else if (xml.isCharacters() && !xml.isWhitespace() && value.isEmpty()) {
                            value = xml.text().toString();
                        } else if (xml.isEndElement() && xml.name() == QStringLiteral("value")) {
                            break;
                        }
                    }
                } else if (xml.isEndElement() && xml.name() == QStringLiteral("member")) {
                    break;
                }
            }
            if (!name.isEmpty()) members[name] = value;
        }
        if (xml.isEndElement() && xml.name() == QStringLiteral("struct"))
            break;
    }
    return members;
}

OpenSubtitlesClient::OpenSubtitlesClient(HttpClient *http, QObject *parent)
    : QObject(parent), http_(http) {}

void OpenSubtitlesClient::setApiKey(const QString &) {}

void OpenSubtitlesClient::searchByName(const QString &query,
                                        const QString &language) {
    auto langCode = language.isEmpty() ? QStringLiteral("eng") : language;
    if (langCode.length() == 2) {
        static const QMap<QString, QString> iso2to3 = {
            {"en", "eng"}, {"nl", "dut"}, {"fr", "fre"}, {"de", "ger"},
            {"es", "spa"}, {"pt", "por"}, {"it", "ita"}, {"pl", "pol"},
            {"ru", "rus"}, {"ar", "ara"}, {"zh", "chi"}, {"ja", "jpn"},
            {"ko", "kor"}, {"tr", "tur"}, {"sv", "swe"}, {"da", "dan"},
            {"no", "nor"}, {"fi", "fin"}, {"cs", "cze"}, {"hu", "hun"},
            {"ro", "rum"}, {"el", "gre"}, {"he", "heb"}, {"th", "tha"},
        };
        langCode = iso2to3.value(langCode, langCode);
    }

    auto loginBody = buildXmlRpc(QStringLiteral("LogIn"), [](QXmlStreamWriter &xml) {
        writeStringParam(xml, QString());
        writeStringParam(xml, QString());
        writeStringParam(xml, QStringLiteral("en"));
        writeStringParam(xml, kUserAgent);
    });

    QNetworkRequest req{QUrl{kApiUrl}};
    req.setHeader(QNetworkRequest::ContentTypeHeader, "text/xml");
    auto *loginReply = http_->post(req, loginBody);

    connect(loginReply, &QNetworkReply::finished, this,
            [this, loginReply, query, langCode]() {
        loginReply->deleteLater();
        if (loginReply->error() != QNetworkReply::NoError) {
            emit errorOccurred(loginReply->errorString());
            return;
        }

        QXmlStreamReader xml(loginReply->readAll());
        QString token;
        while (!xml.atEnd()) {
            xml.readNext();
            if (xml.isStartElement() && xml.name() == QStringLiteral("struct")) {
                auto members = parseStructMembers(xml);
                token = members.value(QStringLiteral("token"));
                break;
            }
        }

        if (token.isEmpty()) {
            emit errorOccurred(QStringLiteral("Login failed"));
            return;
        }

        doSearch(token, query, langCode);
    });
}

void OpenSubtitlesClient::doSearch(const QString &token, const QString &query,
                                    const QString &langCode) {
    auto body = buildXmlRpc(QStringLiteral("SearchSubtitles"),
                            [&](QXmlStreamWriter &xml) {
        writeStringParam(xml, token);
        xml.writeStartElement(QStringLiteral("param"));
        xml.writeStartElement(QStringLiteral("value"));
        xml.writeStartElement(QStringLiteral("array"));
        xml.writeStartElement(QStringLiteral("data"));
        xml.writeStartElement(QStringLiteral("value"));
        xml.writeStartElement(QStringLiteral("struct"));

        xml.writeStartElement(QStringLiteral("member"));
        xml.writeTextElement(QStringLiteral("name"), QStringLiteral("query"));
        xml.writeStartElement(QStringLiteral("value"));
        xml.writeTextElement(QStringLiteral("string"), query);
        xml.writeEndElement();
        xml.writeEndElement();

        xml.writeStartElement(QStringLiteral("member"));
        xml.writeTextElement(QStringLiteral("name"), QStringLiteral("sublanguageid"));
        xml.writeStartElement(QStringLiteral("value"));
        xml.writeTextElement(QStringLiteral("string"), langCode);
        xml.writeEndElement();
        xml.writeEndElement();

        xml.writeEndElement(); // struct
        xml.writeEndElement(); // value
        xml.writeEndElement(); // data
        xml.writeEndElement(); // array
        xml.writeEndElement(); // value
        xml.writeEndElement(); // param
    });

    QNetworkRequest req{QUrl{kApiUrl}};
    req.setHeader(QNetworkRequest::ContentTypeHeader, "text/xml");
    auto *reply = http_->post(req, body);

    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError) {
            emit errorOccurred(reply->errorString());
            return;
        }

        auto responseData = reply->readAll();
        QXmlStreamReader xml(responseData);
        QVector<SubtitleResult> results;

        int structDepth = 0;
        while (!xml.atEnd()) {
            xml.readNext();
            if (xml.isStartElement() && xml.name() == QStringLiteral("struct")) {
                structDepth++;
                if (structDepth >= 2) {
                    auto members = parseStructMembers(xml);
                    if (members.contains(QStringLiteral("SubFileName"))) {
                        SubtitleResult r;
                        r.id = members.value(QStringLiteral("IDSubtitleFile"));
                        r.fileName = members.value(QStringLiteral("SubFileName"));
                        r.language = members.value(QStringLiteral("LanguageName"));
                        r.downloadCount = members.value(QStringLiteral("SubDownloadsCnt")).toInt();
                        r.downloadUrl = members.value(QStringLiteral("SubDownloadLink"));
                        r.fileId = r.id;
                        qInfo("Subtitle found: '%s' lang=%s url='%s'",
                              qPrintable(r.fileName), qPrintable(r.language),
                              qPrintable(r.downloadUrl.left(80)));
                        results.append(r);
                    }
                }
            } else if (xml.isEndElement() && xml.name() == QStringLiteral("struct")) {
                if (structDepth > 0) structDepth--;
            }
        }

        qInfo("Subtitle search: %d results found", results.size());
        emit searchCompleted(results);
    });
}

void OpenSubtitlesClient::downloadSubtitle(const QString &url,
                                            const QString &outputPath) {
    qInfo("Downloading subtitle from: '%s' to: '%s'", qPrintable(url), qPrintable(outputPath));
    if (url.isEmpty() || !url.startsWith(QStringLiteral("http"))) {
        emit errorOccurred(QStringLiteral("Invalid subtitle download URL: %1").arg(url));
        return;
    }

    auto *reply = http_->get(QUrl(url));
    connect(reply, &QNetworkReply::finished, this, [this, reply, outputPath]() {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError) {
            emit errorOccurred(reply->errorString());
            return;
        }

        auto rawData = reply->readAll();
        bool isGzip = rawData.size() >= 2
            && static_cast<unsigned char>(rawData[0]) == 0x1f
            && static_cast<unsigned char>(rawData[1]) == 0x8b;
        qInfo("Subtitle download: %d bytes, gzip=%d", rawData.size(), isGzip);

        QByteArray data;
        if (isGzip) {
            QProcess gunzip;
            gunzip.start(QStringLiteral("gunzip"), {QStringLiteral("-c")});
            gunzip.write(rawData);
            gunzip.closeWriteChannel();
            gunzip.waitForFinished(5000);
            data = gunzip.readAllStandardOutput();
        } else {
            data = rawData;
        }

        QFile file(outputPath);
        if (!file.open(QIODevice::WriteOnly)) {
            emit errorOccurred(QStringLiteral("Cannot write to %1").arg(outputPath));
            return;
        }
        file.write(data);
        file.close();

        emit downloadCompleted(outputPath);
    });
}

} // namespace iptvxs
