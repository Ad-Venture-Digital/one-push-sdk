Pod::Spec.new do |s|
  s.name             = 'onepush_flutter'
  s.version          = '0.1.0'
  s.summary          = 'Ad Venture One Push - Flutter bridge.'
  s.homepage         = 'https://one.adventuredigital.com'
  s.license          = { :type => 'Proprietary' }
  s.author           = { 'Ad Venture Digital' => 'info@adventuredigital.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  # Çekirdek SPM paketi olarak dağıtılır; CocoaPods ile kullanan uygulama için pod
  # spec'i `one-push-sdk` deposu açılınca yayınlanır (bkz. docs/SOZLESME_ESLEMESI.md).
  s.dependency 'OnePush', '~> 0.1'
  s.platform         = :ios, '15.0'
  s.swift_version    = '5.9'
end
