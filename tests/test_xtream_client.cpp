#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QtTest>

#include "iptvxs/api/xtream_client.h"
#include "iptvxs/api/xtream_response.h"
#include "iptvxs/net/http_client.h"

namespace {

QJsonObject parseJson(const char *json) {
    return QJsonDocument::fromJson(QByteArray(json)).object();
}

} // namespace

class TestXtreamClient : public QObject {
    Q_OBJECT

private slots:
    void testServerInfoFromJson() {
        auto json = parseJson(
            "{\"url\":\"http://example.com\",\"port\":\"8080\","
            "\"https_port\":\"443\",\"server_protocol\":\"http\","
            "\"timezone\":\"Europe/Brussels\",\"timestamp_now\":1713400000,"
            "\"user_info\":{\"username\":\"testuser\",\"password\":\"testpass\","
            "\"status\":\"Active\",\"exp_date\":\"1735689600\","
            "\"is_trial\":\"0\",\"active_cons\":\"1\","
            "\"created_at\":\"1700000000\",\"max_connections\":\"2\","
            "\"allowed_output_formats\":[\"m3u8\",\"ts\"]}}");

        auto info = iptvxs::XtreamServerInfo::fromJson(json);
        QCOMPARE(info.url, "http://example.com");
        QCOMPARE(info.port, 8080);
        QCOMPARE(info.httpsPort, 443);
        QCOMPARE(info.serverProtocol, "http");
        QCOMPARE(info.timezone, "Europe/Brussels");
        QCOMPARE(info.timestampNow, 1713400000LL);
        QCOMPARE(info.userInfo.username, "testuser");
        QCOMPARE(info.userInfo.password, "testpass");
        QCOMPARE(info.userInfo.status, "Active");
        QCOMPARE(info.userInfo.expDate, 1735689600LL);
        QCOMPARE(info.userInfo.isTrial, false);
        QCOMPARE(info.userInfo.maxConnections, 2);
        QCOMPARE(info.userInfo.allowedOutputFormats.size(), 2);
        QCOMPARE(info.userInfo.allowedOutputFormats.at(0), "m3u8");
    }

    void testServerInfoMissingFields() {
        auto json = parseJson("{}");
        auto info = iptvxs::XtreamServerInfo::fromJson(json);
        QVERIFY(info.url.isEmpty());
        QCOMPARE(info.port, 0);
        QVERIFY(info.userInfo.username.isEmpty());
    }

    void testCategoryFromJson() {
        auto json = parseJson(
            "{\"category_id\":\"5\",\"category_name\":\"Sports\",\"parent_id\":0}");

        auto cat = iptvxs::XtreamCategory::fromJson(json);
        QCOMPARE(cat.categoryId, "5");
        QCOMPARE(cat.categoryName, "Sports");
        QCOMPARE(cat.parentId, 0);
    }

    void testCategoryNumericId() {
        auto json = parseJson(
            "{\"category_id\":42,\"category_name\":\"Movies\",\"parent_id\":1}");

        auto cat = iptvxs::XtreamCategory::fromJson(json);
        QCOMPARE(cat.categoryId, "42");
        QCOMPARE(cat.categoryName, "Movies");
    }

    void testStreamFromJson() {
        auto json = parseJson(
            "{\"num\":1,\"name\":\"BBC One\",\"stream_type\":\"live\","
            "\"stream_id\":\"12345\",\"stream_icon\":\"http://example.com/logo.png\","
            "\"epg_channel_id\":\"bbc1.uk\",\"added\":\"1700000000\","
            "\"category_id\":\"5\",\"custom_sid\":\"\","
            "\"tv_archive\":1,\"direct_source\":\"\","
            "\"tv_archive_duration\":7}");

        auto stream = iptvxs::XtreamStream::fromJson(json);
        QCOMPARE(stream.num, 1LL);
        QCOMPARE(stream.name, "BBC One");
        QCOMPARE(stream.streamType, "live");
        QCOMPARE(stream.streamId, "12345");
        QCOMPARE(stream.streamIcon, "http://example.com/logo.png");
        QCOMPARE(stream.epgChannelId, "bbc1.uk");
        QCOMPARE(stream.added, 1700000000LL);
        QCOMPARE(stream.categoryId, "5");
        QCOMPARE(stream.tvArchive, 1);
        QCOMPARE(stream.tvArchiveDuration, 7);
    }

    void testStreamMissingFields() {
        auto json = parseJson("{\"name\":\"Test Channel\"}");
        auto stream = iptvxs::XtreamStream::fromJson(json);
        QCOMPARE(stream.name, "Test Channel");
        QCOMPARE(stream.num, 0LL);
        QVERIFY(stream.streamIcon.isEmpty());
    }

    void testBuildApiUrlBasic() {
        iptvxs::HttpClient http;
        iptvxs::XtreamClient client(&http, "http://iptv.example.com:8080",
                                    "myuser", "mypass");

        auto url = client.buildApiUrl({});
        QCOMPARE(url.host(), "iptv.example.com");
        QCOMPARE(url.port(), 8080);
        QCOMPARE(url.path(), "/player_api.php");
        QVERIFY(url.toString().contains("username=myuser"));
        QVERIFY(url.toString().contains("password=mypass"));
    }

    void testBuildApiUrlWithAction() {
        iptvxs::HttpClient http;
        iptvxs::XtreamClient client(&http, "http://iptv.example.com",
                                    "user", "pass");

        auto url = client.buildApiUrl("get_live_categories");
        QVERIFY(url.toString().contains("action=get_live_categories"));
    }

    void testBuildApiUrlWithCategoryId() {
        iptvxs::HttpClient http;
        iptvxs::XtreamClient client(&http, "http://iptv.example.com",
                                    "user", "pass");

        auto url = client.buildApiUrl("get_live_streams", "5");
        QVERIFY(url.toString().contains("action=get_live_streams"));
        QVERIFY(url.toString().contains("category_id=5"));
    }
};

QTEST_MAIN(TestXtreamClient)
#include "test_xtream_client.moc"
