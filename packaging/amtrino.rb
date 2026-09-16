# Cask for the amtrino menu bar companion. Lives in the tap
# (arian-shamaei/homebrew-anthropometer) next to the amtr formula; this copy
# is the source of truth, synced there on release.
#
# Release flow (until CI owns it): sh packaging/build-menubar.sh <version>,
# then `ditto -c -k --keepParent menubar/.build/amtrino.app amtrino-<version>.zip`,
# attach the zip to the GitHub release, and fill sha256 below.
cask "amtrino" do
  version "0.3.1"
  sha256 "cc29bc5a2346ab15b14f56337684e1565e84cc96be2e33c65f1889be4e6f34e6"

  url "https://github.com/arian-shamaei/amtrino/releases/download/v#{version}/amtrino-#{version}.zip"
  name "amtrino"
  desc "Live menu bar dots for local AI coding sessions (Claude Code, Codex CLI)"
  homepage "https://github.com/arian-shamaei/amtrino"

  app "amtrino.app"

  zap trash: [
    "~/Library/Preferences/dev.arian-shamaei.amtrino.plist",
  ]
end
