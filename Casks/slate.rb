cask "slate" do
  version "1.0.25"
  sha256 "dc5064f8f65f7f71c45c00ef66b5c11d48b8aa889ae1a6038a330b1b2ac48d0c"

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
