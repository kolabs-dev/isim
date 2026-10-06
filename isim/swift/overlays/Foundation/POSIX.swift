// isim Foundation: C library pieces that Apple's Swift Darwin overlay provides and that isim has no Swift
// Darwin overlay for (self-authored). `errno` is a macro in C (`*__error()`), which Swift cannot import.
import Darwin

/// The calling thread's errno (Darwin values; isim's libSystem translates the host's)
public var errno: Int32 {
    get { __error().pointee }
    set { __error().pointee = newValue }
}
