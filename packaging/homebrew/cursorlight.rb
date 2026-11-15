# Homebrew cask for Cursorlight. Lives in the tap repository Zawalid/homebrew-cursorlight as Casks/cursorlight.rb.
# `scripts/cask.sh <version>` prints this file with the version and the DMG's SHA-256 filled in.
cask "cursorlight" do
  version "@VERSION@"
  sha256 "@SHA256@"

  url "https://github.com/Zawalid/Cursorlight/releases/download/v#{version}/Cursorlight-#{version}.dmg"
  name "Cursorlight"
  desc "Find, point and mark up with your cursor while you share your screen"
  homepage "https://cursorlight.example.com"

  depends_on macos: :sonoma

  app "Cursorlight.app"

  zap trash: [
    "~/Library/Application Support/Cursorlight",
    "~/Library/Caches/app.cursorlight.mac",
    "~/Library/Preferences/app.cursorlight.mac.plist",
  ]

  caveats <<~EOS
    Cursorlight is not signed with an Apple Developer ID yet, so macOS blocks it the first time you open it.
    Choose Open Anyway in System Settings, Privacy & Security, or run:
      xattr -dr com.apple.quarantine #{appdir}/Cursorlight.app
    Cursorlight needs no permission to start. Input Monitoring is optional, for the double-tap and hold gestures.
  EOS
end
