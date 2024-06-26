
Pod::Spec.new do |s|
  s.name             = 'Percept'
  s.version          = '1.0.2'
  s.summary          = 'Effortlessly integrate Percept into your iOS app.'

  s.homepage         = 'https://perceptinsight.com'
  s.license          = { :type => 'MIT', :file => 'LICENSE.md' }
  s.author           = { 'Percept' => 'tech@perceptinsight.com' }
  s.source           = { :git => 'https://github.com/udaan-com/percept-ios.git', :tag => s.version.to_s }

  s.ios.deployment_target = '13.0'
  s.swift_version = '5.0'

  s.source_files = 'Sources/percept-ios/**/*'
  s.dependency 'Alamofire', '~> 5.0'
  s.exclude_files = [ 'scripts/*']
end
