import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

// Set as accessory app (no dock icon)
app.setActivationPolicy(.accessory)

app.run()
