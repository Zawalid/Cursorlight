# Homebrew cask for Beacon. Lives in the tap repository Zawalid/homebrew-beacon as Casks/beacon.rb.
# `scripts/cask.sh <version>` prints this file with the version and the DMG's SHA-256 filled in.
cask "beacon" do
  version "@VERSION@"
  sha256 "@SHA256@"

  url "https://github.com/Zawalid/Beacon/releases/download/v#{version}/Beacon-#{version}.dmg"
  name "Beacon"
  desc "Find, point and mark up with your cursor while you share your screen"
  homepage "https://beacon.example.com"

  depends_on macos: :sonoma

  app "Beacon.app"

  zap trash: [
    "~/Library/Application Support/Beacon",
    "~/Library/Caches/app.beacon.mac",
    "~/Library/Preferences/app.beacon.mac.plist",
  ]

  caveats <<~EOS
    Beacon is not signed with an Apple Developer ID yet, so macOS blocks it the first time you open it.
    Choose Open Anyway in System Settings, Privacy & Security, or run:
      xattr -dr com.apple.quarantine #{appdir}/Beacon.app
    Beacon needs no permission to start. Input Monitoring is optional, for the double-tap and hold gestures.
  EOS
end
