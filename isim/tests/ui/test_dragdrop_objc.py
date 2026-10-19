"""Drag and drop from Objective-C (HelloDragDropObjC, issue #245): UIKit's Objective-C interface over the Swift
overlay's drag and drop, which UIKit loads on first use. A UIDragInteraction source and a UIDropInteraction target
with Objective-C delegates (sessions: locationInView:, items, localObject, canLoadObjectsOfClass:,
loadObjectsOfClass:completion:), a table view's and a collection view's dragDelegate / dropDelegate with their drop coordinators, a text
field's textDropDelegate, a UISpringLoadedInteraction's activation handler and a UIPasteConfiguration."""


def test_dragdrop_objc(launch):
    app = launch("HelloDragDropObjC")
    app.wait_log(r"^dd interactions drag=1 delegate=1 enabled=1 default=1 drop=1$")
    app.wait_log(r"^dd table delegates drag=1 drop=1 enabled=1 active=0$")
    app.wait_log(r"^dd field drop delegate=1 interaction=1$")
    app.wait_log(r"^dd grid delegates drag=1 drop=1$")
    app.wait_log(r"^dd paste text=1 png=1 same=1$")
    app.wait_log(r"^dd proposals op=2 precise=1 table=3 intent=1$")

    # a drop interaction: the target loads the string
    app.send("longdrag 95 130 295 130 0.7 0.5")
    app.wait_log(r"^dd drag begins at 75,30$")                       # locationInView: of the source
    app.wait_log(r"^dd drag session items=1 local=Apple$")
    app.wait_log(r"^dd target got Apple$")
    app.wait_log(r"^dd drag ended operation=2$")                     # UIDropOperationCopy
    app.wait_view(r"id=target text=Apple")

    # a table view's drop delegate, at the destination row
    app.send("longdrag 95 130 200 330 0.7 0.5")
    app.wait_log(r"^dd table drop items=1 at 1 intent=1$")
    app.wait_log(r"^dd table rows One,Apple,Two,Three$")

    # a text field's text drop delegate
    app.send("longdrag 95 130 200 492 0.7 0.5")
    app.wait_log(r"^dd field drop entered$")
    app.wait_log(r"^dd field proposal same=0 action=0$")
    app.wait_log(r"^dd field text 'Apple'$")

    # a spring-loaded button under a resting drag
    app.send("longdrag 95 130 95 202 0.7 0.5 2")
    app.wait_log(r"^dd spring activated state=3 view=1$")

    # a table row dragged out by the table's drag delegate
    app.send("longdrag 60 282 60 420 0.7 0.5")
    app.wait_log(r"^dd table drag row 0$")
    app.wait_log(r"^dd table drop items=1 at 3 intent=1$")            # over the fourth row
    app.wait_log(r"^dd table rows One,Apple,Two,One,Three$")

    # a collection view: a drop from the source at the first item, then an item dragged within it
    app.send("longdrag 95 130 40 580 0.7 0.5")
    app.wait_log(r"^dd grid drop items=1 at 0 source=0$")
    app.wait_log(r"^dd grid tiles Apple,A,B,C$")
    app.send("longdrag 130 580 380 580 0.7 0.5")
    app.wait_log(r"^dd grid drag item 1$")
    app.wait_log(r"^dd grid drop items=1 at \d source=1$")
    app.wait_log(r"^dd grid tiles Apple,A,B,C,A$|^dd grid tiles Apple,A,B,A,C$")
    assert app.quit() == 0, "exits cleanly"
