require "json"
package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  s.name         = "onepush-react-native"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = package["homepage"]
  s.license      = { :type => "Proprietary" }
  s.authors      = { "Ad Venture Digital" => "info@adventuredigital.com" }
  s.platforms    = { :ios => "15.0" }
  s.source       = { :path => "." }
  s.source_files = "ios/**/*.{h,m,swift}"
  s.swift_version = "5.9"
  s.dependency "React-Core"
  # Çekirdek pod spec'i depo açılınca yayınlanır (SPM paketi şimdiden hazır).
  s.dependency "OnePush", "~> 0.1"
end
