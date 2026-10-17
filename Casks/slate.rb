cask "slate" do
  version "1.0.25"
  sha256 "58265dea0ed44cccb320b5e3c693c922b489fba4e3cd2e35ea4ded61fe8a9f8e"

  # Universal build: runs natively on Apple Silicon and Intel.
  url "https://github.com/nuclearg/slate/releases/download/v#{version}/Slate-#{version}.dmg"
  name "Slate"
  desc "Keyboard-driven window manager (maintained arm64 fork)"
  homepage "https://github.com/nuclearg/slate"

  # The app is built for macOS 11.0+ (arm64 minimum).
  depends_on macos: :big_sur

  app "Slate.app"

  caveats <<~EOS
    Slate controls other apps' windows through the Accessibility API.
    Enable it once after installing:

      System Settings → Privacy & Security → Accessibility → Slate

    Auto-update is disabled in this fork: "Check for Updates" is a no-op.
    Configuration lives in ~/.slate (or ~/.slate.js).
  EOS
end
