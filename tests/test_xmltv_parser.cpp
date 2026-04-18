#include <QtTest>

#include "iptvxs/parser/xmltv_parser.h"

class TestXmltvParser : public QObject {
    Q_OBJECT

private slots:
    void testParseBasic() {
        QByteArray xml = R"(<?xml version="1.0" encoding="UTF-8"?>
<tv>
  <channel id="ch1">
    <display-name>Channel 1</display-name>
  </channel>
  <programme start="20260418080000 +0200" stop="20260418090000 +0200" channel="ch1">
    <title>Morning News</title>
    <desc>Daily news broadcast</desc>
  </programme>
  <programme start="20260418090000 +0200" stop="20260418100000 +0200" channel="ch1">
    <title>Talk Show</title>
  </programme>
</tv>)";

        iptvxs::XmltvParser parser;
        auto programmes = parser.parse(xml);

        QCOMPARE(programmes.size(), 2);
        QCOMPARE(programmes[0].epgChannelId, "ch1");
        QCOMPARE(programmes[0].title, "Morning News");
        QCOMPARE(programmes[0].description, "Daily news broadcast");
        QVERIFY(programmes[0].startTime > 0);
        QVERIFY(programmes[0].endTime > programmes[0].startTime);
        QCOMPARE(programmes[1].title, "Talk Show");
    }

    void testParseEmpty() {
        QByteArray xml = R"(<?xml version="1.0"?><tv></tv>)";
        iptvxs::XmltvParser parser;
        auto programmes = parser.parse(xml);
        QCOMPARE(programmes.size(), 0);
    }

    void testParseMissingTitle() {
        QByteArray xml = R"(<?xml version="1.0"?>
<tv>
  <programme start="20260418080000 +0000" stop="20260418090000 +0000" channel="ch1">
  </programme>
</tv>)";

        iptvxs::XmltvParser parser;
        auto programmes = parser.parse(xml);
        QCOMPARE(programmes.size(), 0);
    }

    void testParseNoTimezone() {
        QByteArray xml = R"(<?xml version="1.0"?>
<tv>
  <programme start="20260418080000" stop="20260418090000" channel="ch1">
    <title>No TZ</title>
  </programme>
</tv>)";

        iptvxs::XmltvParser parser;
        auto programmes = parser.parse(xml);
        QCOMPARE(programmes.size(), 1);
        QVERIFY(programmes[0].startTime > 0);
    }
};

QTEST_GUILESS_MAIN(TestXmltvParser)

#include "test_xmltv_parser.moc"
