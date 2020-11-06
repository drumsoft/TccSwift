#
# Be sure to run `pod lib lint TccSwift.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'TccSwift'
  s.version          = '0.1.0'
  s.summary          = 'toio Core Cube library for Swift and iOS.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
  Library for communicating with toio Core Cubes using Swift and iOS.
                       DESC

  s.homepage         = 'https://github.com/drumsoft/TccSwift'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'drumsoft' => 'hrk8@drumsoft.com' }
  s.source           = { :git => 'https://github.com/drumsoft/TccSwift.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/hrk'

  s.ios.deployment_target = '10.3'

  s.source_files = 'TccSwift/Classes/**/*'
  
  # s.resource_bundles = {
  #   'TccSwift' => ['TccSwift/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
end
