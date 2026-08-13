# Cask for the amtrino menu bar companion. Lives in the tap
# (arian-shamaei/homebrew-anthropometer) next to the amtr formula; this copy
# is the source of truth, synced there on release.
#
# Release flow (until CI owns it): sh packaging/build-menubar.sh <version>,
# then `ditto -c -k --keepParent menubar/.build/amtrino.app amtrino-<version>.zip`,
# attach the zip to the GitHub release, and fill sha256 below.
cask "amtrino" do
  version "0.1.0"
  sha256 "33786330cd939688eeed3a84b9f680eae3ca53bb00adee5d3c1bf52a3a66b00e"

  url "https://github.com/arian-shamaei/amtrino/releases/download/v#{version}/amtrino-#{version}.zip"
  name "amtrino"
  desc "Menu bar companion for amtr: live Claude Code session dots and context gauge"
  homepage "https://github.com/arian-shamaei/amtrino"

  depends_on macos: ">= :ventura"

  app "amtrino.app"

  zap trash: [
    "~/Library/Preferences/dev.arian-shamaei.amtrino.plist",
  ]
end
