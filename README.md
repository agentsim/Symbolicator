This is a simple replacement for Xcode/symbolicatecrash for iOS/OSX crash dumps.

It *should* support 32-bit/64-bit ARM and x86 crash reports. It uses Spotlight to locate dSYMs much the same way symbolicatecrash does.
It should be simple enough to extend it to allow you to specify the build to use for symbols allowing you to rebuild with a known codebase if you no longer have the original build.
Some pretty-ing up of the output is probably in order ;)
