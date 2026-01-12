platform :ios, '16.0'

target 'Cookies' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for Cookies

# Add the Firebase pod for Google Analytics
pod 'FirebaseAnalytics', '~> 11.0'

# For Analytics without IDFA collection capability, use this pod instead
# pod FirebaseAnalytics/Core

# Add the pods for any other Firebase products you want to use in your app
# For example, to use Firebase Authentication and Cloud Firestore
pod 'FirebaseAuth', '~> 11.0'
pod 'FirebaseFirestore', '~> 11.0'
pod 'FirebaseAppCheck', '~> 11.0'

  target 'CookiesTests' do
    inherit! :search_paths
  end

end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      # Fix for "unsupported option '-G'" in BoringSSL-GRPC and gRPC-Core
      # Remove from build settings
      ['GCC_PREPROCESSOR_DEFINITIONS', 'OTHER_CFLAGS', 'OTHER_CPLUSPLUSFLAGS', 'WARNING_CFLAGS'].each do |setting|
        if config.build_settings[setting]
          if config.build_settings[setting].kind_of?(Array)
             config.build_settings[setting].delete_if { |item| item.include?('-G') }
          elsif config.build_settings[setting].kind_of?(String)
             config.build_settings[setting] = config.build_settings[setting].gsub(/-G\S*/, '').gsub(/-G/, '')
          end
        end
      end

      # Fix for Swift 6.x compatibility with Firebase modules
      config.build_settings['BUILD_LIBRARY_FOR_DISTRIBUTION'] = 'NO'
      config.build_settings['SWIFT_STRICT_CONCURRENCY'] = 'minimal'

      # Ensure consistent deployment target
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '16.0'
    end

    # Remove from file-specific compiler flags
    if target.respond_to?(:source_build_phase)
      target.source_build_phase.files.each do |file|
        if file.settings && file.settings['COMPILER_FLAGS']
          file.settings['COMPILER_FLAGS'] = file.settings['COMPILER_FLAGS'].gsub(/-G\S*/, '').gsub(/-G/, '')
        end
      end
    end
  end
end
