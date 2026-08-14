# Cask for the amtrino menu bar companion. Lives in the tap
# (arian-shamaei/homebrew-anthropometer) next to the amtr formula; this copy
# is the source of truth, synced there on release.
#
# Release flow (until CI owns it): sh packaging/build-menubar.sh <version>,
# then `ditto -c -k --keepParent menubar/.build/amtrino.app amtrino-<version>.zip`,
# attach the zip to the GitHub release, and fill sha256 below.
cask "amtrino" do
  version "0.3.0"
  sha256 "43e0a5986f854de775e23285315dc60faacfb644da8ccd3b6ec07681345a9e76"

  url "https://github.com/arian-shamaei/amtrino/releases/download/v#{version}/amtrino-#{version}.zip"
  name "amtrino"
  desc "Live menu bar dots for local AI coding sessions (Claude Code, Codex CLI)"
  homepage "https://github.com/arian-shamaei/amtrino"

  app "amtrino.app"

  zap trash: [
    "~/Library/Preferences/dev.arian-shamaei.amtrino.plist",
  ]
end
