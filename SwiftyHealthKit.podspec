Pod::Spec.new do |s|
  s.name             = 'SwiftyHealthKit'
  s.version          = '0.2.0'
  s.summary          = 'Thin wrapper for iOS HealthKit to use it swifty.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
  SwiftyHealthKit is a thin wrapper for iOS HealthKit for iOS8.0+, Swift3.0+.
  In most cases, I think that dealing with the data of HealthKit by day.
  So SwiftyHealthKit dealing with the data by day.
                       DESC

  s.homepage         = 'https://github.com/abeyuya/SwiftyHealthKit'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'abeyuya' => 'yuya.abe.0525@gmail.com' }
  s.source           = { :git => 'https://github.com/abeyuya/SwiftyHealthKit.git', :tag => s.version.to_s }
  s.ios.deployment_target = '8.0'

  s.source_files = 'SwiftyHealthKit/Classes/**/*'
  s.frameworks = 'HealthKit'
end
