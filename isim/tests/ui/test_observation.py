"""Observation (HelloObservation): an @Observable store in @State passed with .environment(_:),
@Environment(Store.self), @Bindable bindings (TextField, Toggle), computed properties updating views.
Port of tests/ui/observation.sh."""


def test_observation(launch):
    app = launch("HelloObservation")
    first = app.wait_view(r"text=2 remaining")
    assert "text=Walk the dog" in first, "@Environment(Store.self) renders the store"

    app.tap_id("task-Buy_milk")
    app.wait_log(r"^remaining 1")                                      # @Bindable Toggle updates an @Observable item
    app.tap_id("draft")
    app.type("Eggs")
    app.tap_id("add")
    app.wait_log(r"added Eggs")                                        # @Bindable TextField + method on the store
    app.wait_log(r"^remaining 2")
    app.wait_view(r"text=Eggs")
    app.tap_id("task-Eggs")
    app.wait_view(r"text=1 remaining")                                 # computed property re-renders
    app.screenshot("tasks")
    assert app.quit() == 0, "exits cleanly"
