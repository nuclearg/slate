cask "slate-amd64" do
  version "1.0.25"
  sha256 "8810aa515758783da4a6c95f97d85d41803304d89aad186a565cbc3fee7c2a9f"

  # Universal build: runs natively on Apple Silicon and Intel.
  url "https://github.com/nuclearg/slate/releases/download/v#{version}/Slate-#{version}-universal.zip"
  name "Slate"
  desc "Keyboard-driven window manager (arm64 fork of Slate)"
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
