#include <QBuffer>
#include <QSignalSpy>
#include <QtTest>

#include "iptvxs/parser/m3u_parser.h"

class TestM3uParser : public QObject {
    Q_OBJECT

private slots:
    void testBasicParsing() {
        QByteArray data =
            "#EXTM3U\n"
            "#EXTINF:-1 tvg-id=\"bbc1\" tvg-logo=\"http://logo.com/bbc.png\" "
            "group-title=\"UK\",BBC One\n"
            "http://stream.example.com/bbc1\n"
            "#EXTINF:-1 tvg-id=\"itv\" group-title=\"UK\",ITV\n"
            "http://stream.example.com/itv\n"
            "#EXTINF:-1 group-title=\"Sports\",Sky Sports\n"
            "http://stream.example.com/sky\n";

        QBuffer buffer(&data);
        buffer.open(QIODevice::ReadOnly);

        iptvxs::M3uParser parser;
        auto channels = parser.parseAll(&buffer, 1);

        QCOMPARE(channels.size(), 3);

        QCOMPARE(channels[0].name, "BBC One");
        QCOMPARE(channels[0].epgChannelId, "bbc1");
        QCOMPARE(channels[0].logoUrl, "http://logo.com/bbc.png");
        QCOMPARE(channels[0].streamUrl, "http://stream.example.com/bbc1");
        QCOMPARE(channels[0].serverId, 1LL);

        QCOMPARE(channels[1].name, "ITV");
        QCOMPARE(channels[1].epgChannelId, "itv");

        QCOMPARE(channels[2].name, "Sky Sports");
    }

    void testCategoryDiscovery() {
        QByteArray data =
            "#EXTM3U\n"
            "#EXTINF:-1 group-title=\"UK\",BBC One\n"
            "http://stream1\n"
            "#EXTINF:-1 group-title=\"UK\",BBC Two\n"
            "http://stream2\n"
            "#EXTINF:-1 group-title=\"Sports\",Sky Sports\n"
            "http://stream3\n";

        QBuffer buffer(&data);
        buffer.open(QIODevice::ReadOnly);

        iptvxs::M3uParser parser;
        QSignalSpy categorySpy(&parser, &iptvxs::M3uParser::categoryDiscovered);

        parser.parseAll(&buffer, 1);

        QCOMPARE(categorySpy.count(), 2);
        QCOMPARE(categorySpy.at(0).at(0).toString(), "UK");
        QCOMPARE(categorySpy.at(1).at(0).toString(), "Sports");
    }

    void testWindowsLineEndings() {
        QByteArray data =
            "#EXTM3U\r\n"
            "#EXTINF:-1,Test Channel\r\n"
            "http://stream.example.com/test\r\n";

        QBuffer buffer(&data);
        buffer.open(QIODevice::ReadOnly);

        iptvxs::M3uParser parser;
        auto channels = parser.parseAll(&buffer, 1);

        QCOMPARE(channels.size(), 1);
        QCOMPARE(channels[0].name, "Test Channel");
        QCOMPARE(channels[0].streamUrl, "http://stream.example.com/test");
    }

    void testUtf8Bom() {
        QByteArray data = "\xEF\xBB\xBF#EXTM3U\n"
                          "#EXTINF:-1,BOM Channel\n"
                          "http://stream\n";

        QBuffer buffer(&data);
        buffer.open(QIODevice::ReadOnly);

        iptvxs::M3uParser parser;
        auto channels = parser.parseAll(&buffer, 1);

        QCOMPARE(channels.size(), 1);
        QCOMPARE(channels[0].name, "BOM Channel");
    }

    void testEmptyFile() {
        QByteArray data = "#EXTM3U\n";

        QBuffer buffer(&data);
        buffer.open(QIODevice::ReadOnly);

        iptvxs::M3uParser parser;
        QSignalSpy finishedSpy(&parser, &iptvxs::M3uParser::finished);

        auto channels = parser.parseAll(&buffer, 1);

        QCOMPARE(channels.size(), 0);
    }

    void testMissingAttributes() {
        QByteArray data =
            "#EXTM3U\n"
            "#EXTINF:-1,Minimal Channel\n"
            "http://stream\n";

        QBuffer buffer(&data);
        buffer.open(QIODevice::ReadOnly);

        iptvxs::M3uParser parser;
        auto channels = parser.parseAll(&buffer, 1);

        QCOMPARE(channels.size(), 1);
        QCOMPARE(channels[0].name, "Minimal Channel");
        QVERIFY(channels[0].epgChannelId.isEmpty());
        QVERIFY(channels[0].logoUrl.isEmpty());
    }

    void testBlankLinesBetweenEntries() {
        QByteArray data =
            "#EXTM3U\n\n"
            "#EXTINF:-1,Channel 1\n\n"
            "http://stream1\n\n\n"
            "#EXTINF:-1,Channel 2\n"
            "http://stream2\n";

        QBuffer buffer(&data);
        buffer.open(QIODevice::ReadOnly);

        iptvxs::M3uParser parser;
        auto channels = parser.parseAll(&buffer, 1);

        QCOMPARE(channels.size(), 2);
    }

    void testTvgNameFallback() {
        QByteArray data =
            "#EXTM3U\n"
            "#EXTINF:-1 tvg-name=\"Named Channel\",\n"
            "http://stream\n";

        QBuffer buffer(&data);
        buffer.open(QIODevice::ReadOnly);

        iptvxs::M3uParser parser;
        auto channels = parser.parseAll(&buffer, 1);

        QCOMPARE(channels.size(), 1);
        QCOMPARE(channels[0].name, "Named Channel");
    }

    void testProgressSignal() {
        QByteArray data = "#EXTM3U\n";
        for (int i = 0; i < 1500; ++i) {
            data += QStringLiteral("#EXTINF:-1,Channel %1\nhttp://s/%1\n").arg(i).toUtf8();
        }

        QBuffer buffer(&data);
        buffer.open(QIODevice::ReadOnly);

        iptvxs::M3uParser parser;
        QSignalSpy progressSpy(&parser, &iptvxs::M3uParser::progressUpdated);

        auto channels = parser.parseAll(&buffer, 1);

        QCOMPARE(channels.size(), 1500);
        QVERIFY(progressSpy.count() >= 1);
        QCOMPARE(progressSpy.at(0).at(0).toInt(), 1000);
    }

    void testLargeFile() {
        QByteArray data = "#EXTM3U\n";
        for (int i = 0; i < 10000; ++i) {
            data += QStringLiteral("#EXTINF:-1 tvg-id=\"ch%1\" group-title=\"Group %2\","
                                   "Channel %1\nhttp://stream/%1\n")
                        .arg(i)
                        .arg(i / 100)
                        .toUtf8();
        }

        QBuffer buffer(&data);
        buffer.open(QIODevice::ReadOnly);

        iptvxs::M3uParser parser;
        auto channels = parser.parseAll(&buffer, 1);

        QCOMPARE(channels.size(), 10000);
        QCOMPARE(channels[0].epgChannelId, "ch0");
        QCOMPARE(channels[9999].name, "Channel 9999");
    }
};

QTEST_MAIN(TestM3uParser)
#include "test_m3u_parser.moc"
