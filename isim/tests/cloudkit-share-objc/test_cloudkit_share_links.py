"""CloudKit share links (issue #575): an app saves a share in its container (iCloud.<bundle ID>); the link
(https://www.icloud.com/share/...) opened in the running app, or launching it (isim-cloudkit-share:<link>, the home
screen's launch for a link of the app's container), hands the share's metadata to the app, which accepts it.
Objective-C without scenes: UIApplicationLaunchOptionsCloudKitShareMetadataKey and
application:userDidAcceptCloudKitShareWithMetadata:. With a scene delegate: the connection options' cloudKitShareMetadata
and windowScene:userDidAcceptCloudKitShareWithMetadata:. Swift: UIScene.ConnectionOptions.cloudKitShareMetadata
(CKShare.Metadata) at launch, and windowScene(_:userDidAcceptCloudKitShareWith:) for a link opened while it runs, written
without @objc (issue #630); CKShare.SystemFieldKey.title as a record field key; the metadata archived and decoded."""
import base64

from isimtest import need_apps


def share_url(app, prefix):
    return app.wait_log(prefix + r"share url (https://www\.icloud\.com/share/\S+)").group(1)


def test_share_link_app_delegate(launch, device_data):
    need_apps("CloudKitShareObjCTest")
    p = "CKShareLink: "
    app = launch("CloudKitShareObjCTest")
    app.wait_log(p + "launch options share none")
    url = share_url(app, p)
    app.send(f"openurl {url}")
    app.wait_log(r"isim: CloudKit share link .* opened in the app")
    app.wait_log(p + r"app delegate share Groceries role 1 container 1 root groceries")
    app.wait_log(p + r"app delegate accepted CKShare error 0")
    assert app.quit() == 0
    app = launch("CloudKitShareObjCTest", data=device_data, env={"ISIM_LAUNCH_URL": f"isim-cloudkit-share:{url}"})
    app.wait_log(p + r"launch options share Groceries role 1 container 1 root groceries")
    app.wait_log(p + r"app delegate share Groceries role 1")
    app.wait_log(p + r"app delegate accepted CKShare error 0")
    assert "share url" not in app.log
    assert app.quit() == 0


def test_share_link_scene_delegate(launch, device_data):
    need_apps("CloudKitShareSceneObjCTest")
    p = "CKShareLink: "
    app = launch("CloudKitShareSceneObjCTest")
    app.wait_log(p + "scene options share none")
    url = share_url(app, p)
    app.send(f"openurl {url}")
    app.wait_log(p + r"scene delegate share Groceries role 1 container 1 root groceries")
    app.wait_log(p + r"scene delegate accepted CKShare error 0")
    assert "app delegate share" not in app.log
    assert app.quit() == 0
    app = launch("CloudKitShareSceneObjCTest", data=device_data, env={"ISIM_LAUNCH_URL": f"isim-cloudkit-share:{url}"})
    app.wait_log(p + r"scene options share Groceries role 1 container 1 root groceries")
    app.wait_log(p + r"scene launch accepted CKShare error 0")
    assert "scene delegate share" not in app.log and "app delegate share" not in app.log
    assert app.quit() == 0


def test_share_link_swift(launch, device_data):
    need_apps("CloudKitShareSwiftTest")
    p = "CKShareLinkSwift: "
    app = launch("CloudKitShareSwiftTest")
    app.wait_log(p + "launch options key UIApplicationLaunchOptionsCloudKitShareMetadataKey")
    app.wait_log(p + "app delegate method objc true")
    app.wait_log(p + "scene options share none")
    url = share_url(app, p)
    app.send(f"openurl {url}")
    app.wait_log(p + r"scene delegate share Share-todo role 1 title Todo archived true")
    assert "app delegate share" not in app.log
    assert app.quit() == 0
    app = launch("CloudKitShareSwiftTest", data=device_data, env={"ISIM_LAUNCH_URL": f"isim-cloudkit-share:{url}"})
    app.wait_log(p + r"scene options share Share-todo role 1")
    app.wait_log(p + r"accepted CKShare public 2")
    assert app.quit() == 0


def test_share_link_other_container(launch):
    """a share link of another app's container is not this app's: it goes to Safari (not shown with isim run)"""
    need_apps("CloudKitShareObjCTest")
    app = launch("CloudKitShareObjCTest")
    app.wait_log("CKShareLink: share url")
    token = base64.urlsafe_b64encode("iCloud.dev.isim.other\x1f__defaultOwner__\x1fShared\x1fShare-x".encode()).decode().rstrip("=")
    app.send(f"openurl https://www.icloud.com/share/{token}")
    app.wait_log(r"is not a universal link of this app: opened in Safari")
    assert "app delegate share" not in app.log
    assert app.quit() == 0


def test_share_link_from_home_screen(launch):
    """under the device shell the home screen routes a share link to the app of its container: launched with it (the
    launch options), then, running, through application:userDidAcceptCloudKitShareWithMetadata:"""
    need_apps("CloudKitShareObjCTest")
    p = "CKShareLink: "
    dev = launch(None, install=["CloudKitShareObjCTest"])
    dev.send("launch dev.isim.tests.CloudKitShareObjCTest")
    url = share_url(dev, p)
    dev.send("terminate dev.isim.tests.CloudKitShareObjCTest")
    dev.wait_log(r"isim shell: \S+CloudKitShareObjCTest\.app exited")
    dev.send(f"openurl {url}")
    dev.wait_log(r"SpringBoard: .* opens the CloudKit share https://www\.icloud\.com/share/")
    dev.wait_log(p + r"launch options share Groceries role 1 container 1 root groceries")
    dev.wait_log(p + r"app delegate accepted CKShare error 0")
    dev.send("home")
    dev.send(f"openurl {url}")
    dev.wait_log(p + r"app delegate share Groceries role 1", count=2)
