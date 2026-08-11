#!/usr/bin/env ruby
# xcode_register.rb
# Registers TrezorBridge.xcframework and TrezorBridgeFFI.swift into the
# Runner Xcode project so they are compiled and linked automatically.
#
# Usage: ruby xcode_register.rb
# Run from any directory; paths are resolved relative to this script.

require 'xcodeproj'
require 'pathname'

SCRIPT_DIR  = Pathname.new(__FILE__).dirname.realpath
REPO_ROOT   = (SCRIPT_DIR / '../../..').cleanpath
IOS_DIR     = REPO_ROOT / 'ios'
PROJECT     = IOS_DIR / 'Runner.xcodeproj'
XCFW_NAME   = 'TrezorBridge.xcframework'
SWIFT_NAME  = 'TrezorBridgeFFI.swift'
XCFW_PATH   = IOS_DIR / 'Runner' / XCFW_NAME
SWIFT_PATH  = IOS_DIR / 'Runner' / SWIFT_NAME

abort "XCFramework not found: #{XCFW_PATH}" unless XCFW_PATH.exist?
abort "Swift binding not found: #{SWIFT_PATH}" unless SWIFT_PATH.exist?

proj = Xcodeproj::Project.open(PROJECT)
target = proj.targets.find { |t| t.name == 'Runner' }
abort 'Runner target not found in Xcode project' unless target

# --- Helper: check if a file reference with this path already exists ----------
def already_registered?(group, name)
  group.files.any? { |f| f.path&.end_with?(name) }
end

# --- 1. Register TrezorBridgeFFI.swift into Runner group --------------------
runner_group = proj.main_group['Runner'] ||
               proj.main_group.new_group('Runner', 'Runner')

unless already_registered?(runner_group, SWIFT_NAME)
  swift_ref = runner_group.new_file(SWIFT_PATH.to_s)
  target.source_build_phase.add_file_reference(swift_ref)
  puts "Added #{SWIFT_NAME} to Compile Sources"
else
  puts "#{SWIFT_NAME} already registered — skipping"
end

# --- 2. Register TrezorBridge.xcframework as an embedded framework -----------
fw_group = proj.main_group['Frameworks'] ||
           proj.main_group.new_group('Frameworks')

unless already_registered?(fw_group, XCFW_NAME)
  fw_ref = fw_group.new_file(XCFW_PATH.to_s)
  fw_ref.last_known_file_type = 'wrapper.xcframework'

  # Add to "Link Binary With Libraries" phase
  target.frameworks_build_phase.add_file_reference(fw_ref)

  # Static XCFramework: Do Not Embed (settings = 0)
  build_file = target.frameworks_build_phase.files.find do |f|
    f.file_ref == fw_ref
  end
  build_file.settings = { 'ATTRIBUTES' => [] } if build_file

  puts "Added #{XCFW_NAME} to Frameworks (Do Not Embed)"
else
  puts "#{XCFW_NAME} already registered — skipping"
end

proj.save
puts "\nproject.pbxproj updated successfully."
puts "Open Xcode and build (⌘B) to verify."
