"""CloudKit from Objective-C (CloudKitObjCTest.app, issue #573): #import <CloudKit/CloudKit.h> over isim's local
CloudKit. The container and account, typed record values (a list, a date, data, a location, a reference, an asset, an
encrypted value) and system-field archiving, the database's convenience methods, modify and fetch operations with a
serverRecordChanged conflict and partial failures, a paged query, a custom zone with its changes and an archived change
token, database changes, subscriptions with an in-process push to the Objective-C app delegate, a parsed notification,
a share and its metadata, the sharing options, and the CKSyncEngine enums."""
from isimtest import need_apps


def test_cloudkit_objc(launch):
    need_apps("CloudKitObjCTest")
    app = launch("CloudKitObjCTest")
    p = "CloudKitObjC: "
    app.wait_log(p + r"container iCloud\.dev\.isim\.tests\.CloudKitObjCTest account 1 user 1 scopes 2 1 3 other iCloud\.dev\.isim\.tests\.other")
    app.wait_log(p + r"record Note n1 keys blob,count,file,rating,ref,secret,tags,title,when,where changed 10 parent 1 zone _defaultZone")
    app.wait_log(p + r"saved tag 1 fetched title=First count=1 rating=1\.5 tags=isim\+objc when=1000 blob=5 lat=38\.33 ref=1 action=1 "
                     r"asset=asset bytes secret=hidden created 1")
    app.wait_log(p + r"system fields n1 tag 1 keys 0 missing CKErrorDomain 11")
    app.wait_log(p + r"modify n2:ok,n3:ok,n1:14 saved 2 error 2 partial 1 conflict server=First \(phone\) client=First \(stale\) atomic 0 qos 25")
    app.wait_log(p + r"fetch n2:Second,gone:11 found 1 error 2 desired Second count nil")
    app.wait_log(p + r"delete n3:ok")
    app.wait_log(p + r"query First \(phone\),Second cursor 1 more 0 max 0")
    app.wait_log(p + r"zones saved Work caps 7 all Work,_defaultZone per 2 default _defaultZone")
    app.wait_log(p + r"zone changes w1,w2 token 1 more 0 since: changed 0 deleted w2:Note")
    app.wait_log(p + r"database changes Work,_defaultZone token 1")
    app.wait_log(p + r"subscriptions types 1,2 all 2 urgent Note options 1 alert An urgent note")
    app.wait_log(p + r"push CKQueryNotification subscription urgent reason 1 record u1 alert An urgent note")
    app.wait_log(p + r"push CKRecordZoneNotification subscription 1")
    app.wait_log(p + r"parsed CKQueryNotification type 1 sub urgent reason 3 record n9 scope 2 pruned 0 bogus nil")
    app.wait_log(p + r"subscription deleted urgent")
    app.wait_log(p + r"share CKShare url 1 title Notes public 2 owner role 1 status 2 participants 1 root Share-shared metadata role 1 "
                     r"permission 3 container 1")
    app.wait_log(p + r"sharing options 1 3 standard 3")
    app.wait_log(p + r"sync engine enums 11 2 1 account notification CKAccountChangedNotification")
    app.wait_log(p + r"done")
    assert app.quit() == 0
