cask "wakeintosh" do
  version "1.0"
  sha256 "c22f2554b382a0b06879c2d2dacde141e986b86bb0fb746aa3c33674c4ffa743"

  url "https://github.com/RishikeshSreekumar/wakeintosh/releases/download/v#{version}/Wakeintosh-#{version}.zip"
  name "Wakeintosh"
  desc "Menu bar app to prevent sleep, with an optional timer"
  homepage "https://github.com/RishikeshSreekumar/wakeintosh"

  depends_on macos: :ventura

  app "Wakeintosh.app"

  # The app is ad-hoc signed (not notarized), so clear the quarantine flag
  # to let it launch without a Gatekeeper prompt.
  postflight_steps do
    run "/usr/bin/xattr", args: ["-dr", "com.apple.quarantine", "{{appdir}}/Wakeintosh.app"]
  end

  uninstall quit: "work.mando.wakeintosh"

  zap trash: "~/Library/Preferences/work.mando.wakeintosh.plist"
end
