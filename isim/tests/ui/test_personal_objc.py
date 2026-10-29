"""Location and personal data from Objective-C (HelloPersonalObjC, issue #232): CoreLocation (the permission, location
updates through both authorization callbacks, CLLocation and CLCircularRegion with CLLocationCoordinate2D, CLGeocoder),
MapKit (MKMapView's region, MKPointAnnotation and the app's own <MKAnnotation> class, an MKMarkerAnnotationView from
the delegate, an MKPolyline and its renderer, MKLocalSearch, MKClusterAnnotation, dragging the café's marker), Contacts (saving and finding a contact with
CNLabeledValue phone numbers and emails), ContactsUI (the contact picker and its delegate) and EventKit / EventKitUI
(saving and finding an event, the event editor's delegate)."""
import os
import re

ENV = {"ISIM_LOCATION_PERMISSION": "wheninuse", "ISIM_CONTACTS_PERMISSION": "allow", "ISIM_CALENDAR_PERMISSION": "allow"}


def test_personal_objc(launch):
    app = launch("HelloPersonalObjC", env=ENV)
    app.wait_log(r"^po location services=1 status=0 delegate=1$")
    app.wait_log(r"^po authorization 4$")
    app.wait_log(r"^po authorization status callback 4$")
    app.wait_log(r"^po located 37\.3349,-122\.0090 accuracy=1$")
    app.wait_log(r"^po distance 61 km lat=37\.7749 valid=0$")
    app.wait_log(r"^po region park radius=200 contains=1$")
    app.wait_log(r"^po geocode Cupertino error=nil$")

    app.wait_log(r"^po map region 37\.335,-122\.009 span=0\.0[1-4]\d$")     # 2 km, fitted to the tall view
    app.wait_log(r"^po map features=3 tracking item map=1$")
    app.wait_log(r"^po annotations 2 cafe=1$")
    app.wait_log(r"^po view for Caffè Macs is cafe=1$")
    app.wait_log(r"^po overlay points=3$")
    app.wait_log(r"^po renderer for polyline$")
    app.wait_log(r"^po search error=\S+ items=1$")
    shot = app.wait_shot_still()
    d = os.environ.get("ISIM_SHOTS_DIR")
    if d:
        os.makedirs(d, exist_ok=True)
        shot.save(os.path.join(d, "personal-objc-map.png"))
    # the basemap's own "Apple Park" label makes way for the marker titled Apple Park on that spot (#471)
    dump = app.view_dump()
    assert re.search(r"text=MKMarkerAnnotationView Apple Park", dump), "the marker for Apple Park"
    m = re.search(r"text=map center [^\n]* labels (\S[^\n]*)", dump)
    assert not m or "Apple Park" not in m.group(1).split("|"), f"no basemap label under the marker's title ({m and m.group(1)})"

    # issue #417: a cluster annotation; dragging the café's draggable marker east: the delegate sees each drag state, and
    # the map sets the coordinate through the app's setCoordinate: before ending
    app.wait_log(r"^po cluster members=2 cafe=1 title=nil middle=1$")
    app.wait_log(r"^po cafe draggable=1 state=0 cluster view=nil$")
    m = app.wait_log(r"^po cafe marker at (\d+),(\d+)$")
    x, y = int(m.group(1)), int(m.group(2))
    app.send(f"longdrag {x} {y - 20} {x + 60} {y - 20} 0.8 0.5")
    app.wait_log(r"^po drag Caffè Macs 1 from 0 at 37\.3310,-122\.0040$")
    app.wait_log(r"^po drag Caffè Macs 2 from 1 at 37\.3310,-122\.0040$")
    app.wait_log(r"^po drag Caffè Macs 4 from 2 at 37\.3310,-122\.00[0-3]\d$")
    app.wait_log(r"^po drag Caffè Macs 0 from 4 at 37\.3310,-122\.00[0-3]\d$")

    app.wait_log(r"^po contacts granted=1 saved=1 found=1 name=Dana Objc phone=\+1 555 0100 label=mobile email=dana@example\.com error=nil$")
    app.wait_log(r"^po calendar granted=1 status=3 saved=1 found=1 title=Objective-C sync alarms=1 error=nil$")
    app.wait_log(r"^po recurring saved=1 occurrences=2 weekdays=2 days=5 positions=-1 location=Office radius=100 proximity=1$")

    app.tap_id("pick")                                    # the contact picker, its delegate told of the choice
    app.wait_view(r"text=Dana Objc")
    app.tap_text("Dana Objc")
    app.wait_log(r"^po picked Dana Objc$")

    app.wait_tap_id("event")                              # the event editor, its delegate told it was canceled
    app.wait_view(r"text=Cancel")
    app.tap_text("Cancel")
    app.wait_log(r"^po editor done action=0$")
