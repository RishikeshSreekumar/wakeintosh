cask "wakeintosh" do
  version "1.0"
  sha256 "f414b89d39059ea1ece1f5031aa78247cd91bee888a5af9f8172565ffac8ee25"

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
