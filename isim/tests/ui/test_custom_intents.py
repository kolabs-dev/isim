"""Custom SiriKit intents from an .intentdefinition (HelloCustomIntents, built by `isim build`, issue #214): the
generated classes (OrderSoupIntent with @NSManaged parameters, OrderSoupIntentHandling, OrderSoupIntentResponse with
its code and response factories, the Soup type, the SoupSize enum and their resolution results) compile and work in
the app; isim's Siri runs the intent in the app from `siri intent OrderSoupIntent ...`: the values are converted to
the parameters' types, a missing soup is asked for with the definition's prompt, and Siri speaks the response code's
dialog (success, and the custom soldOut code)."""
import re
from pathlib import Path

from isimtest import ROOT

APP = "dev.isim.samples.HelloCustomIntents"


def test_generated_intent_classes():
    gen = ROOT / "out/projects/HelloCustomIntents/obj/HelloCustomIntents/DerivedSources/IntentDefinitionGenerated/Intents.swift"
    swift = gen.read_text()
    assert "public class OrderSoupIntent: INIntent" in swift and "@NSManaged public var soup: Soup?" in swift
    assert "@objc(resolveSoupForOrderSoup:withCompletion:)" in swift and "@objc(handleOrderSoup:completion:)" in swift
    assert "public static func soldOut(soup: Soup) -> OrderSoupIntentResponse" in swift
    assert "case soldOut = 100" in swift and "@objc public enum SoupSize: Int" in swift
    assert "@objc(provideSoupOptionsCollectionForOrderSoup:withCompletion:)" in swift and \
        "optional func provideSoupOptionsCollection(for intent: OrderSoupIntent, with completion: @escaping (INObjectCollection<Soup>?, Swift.Error?) -> Swift.Void)" in swift, \
        "dynamic options"
    assert "@NSManaged public var price: INCurrencyAmount?" in swift, "a currency amount"
    assert (ROOT / "out/apps/HelloCustomIntents.app/Intents.intentdefinition").is_file(), "the definition in the bundle"


def test_custom_intent_in_app(launch):
    app = launch("HelloCustomIntents")
    app.wait_log(r"^soup intent: Tomato 2 size 2$")
    app.wait_log(r"^soup response: code 4 wait 10 price 9 EUR$")
    assert app.quit() == 0


def test_custom_intent_with_siri(launch):
    dev = launch(None, install=["HelloCustomIntents"])
    dev.send(f"launch {APP}")
    dev.wait_tap_id("allowSiri")
    dev.wait_view(r"text=“Soup Kitchen” Would Like to Use Siri")
    dev.send("taptext Allow")
    dev.wait_log(r"soup Siri authorization 3")
    dev.send("home")

    dev.send("siri intent OrderSoupIntent soup=Tomato quantity=2 size=bowl")
    dev.wait_log(r"soup resolve size: 2")
    dev.wait_log(r"soup handle: 2 Tomato size 2")
    dev.wait_dump(r"id=siri-card text=Your 2 Tomato will be ready in 10 minutes\. That’s €9\.00\.")
    dev.screenshot("custom-intent")
    dev.send("siri dismiss")

    dev.send("siri intent OrderSoupIntent quantity=1")                   # no soup: the definition's prompt and
    dev.wait_dump(r"id=siri-card text=Which soup would you like\?")      # the soup's dynamic options
    dev.wait_dump(r"id=siri-option-2 text=Gazpacho")
    dev.wait_still()
    dev.screenshot("custom-intent-options")
    dev.send("siri Minestrone")
    dev.wait_dump(r"id=siri-card text=Your 1 Minestrone will be ready in 5 minutes\. That’s €4\.50\.")
    dev.send("siri dismiss")
    dev.send("siri intent OrderSoupIntent quantity=1")                   # a soup that is not among the options
    dev.wait_dump(r"id=siri-option-0 text=Tomato")
    dev.send("siri Lentil")
    dev.wait_dump(r"id=siri-card text=Your 1 Lentil will be ready in 5 minutes\.")
    dev.send("siri dismiss")

    dev.send("siri intent OrderSoupIntent soup=Gazpacho")                # the custom soldOut code
    dev.wait_dump(r"id=siri-card text=Sorry, Gazpacho is sold out today\.")
