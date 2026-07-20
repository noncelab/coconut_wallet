# frozen_string_literal: true

require "fastlane_core/ui/ui"

module ProductionReleaseHelper
  UI = FastlaneCore::UI
  IOS_LOCALES = %w[ko en-US ja es-ES de-DE].freeze
  ANDROID_LOCALES = %w[ko-KR en-US ja-JP es-ES de-DE].freeze
  MAX_RELEASE_NOTE_CHARACTERS = 500

  def self.validate_metadata!(root:, platform:, flavor:, version_code: nil)
    locales = platform == "ios" ? IOS_LOCALES : ANDROID_LOCALES
    base = File.join(root, "fastlane", "store_metadata", "generated", platform, flavor)

    paths = locales.map do |locale|
      if platform == "ios"
        File.join(base, locale, "release_notes.txt")
      else
        File.join(base, locale, "changelogs", "#{version_code}.txt")
      end
    end

    paths.each do |path|
      UI.user_error!("Release-note metadata not found: #{path}\nRun $generate-store-release-notes for #{flavor} first.") unless File.file?(path)

      content = File.read(path, encoding: "UTF-8").strip
      UI.user_error!("Release-note metadata is empty: #{path}") if content.empty?
      if content.length > MAX_RELEASE_NOTE_CHARACTERS
        UI.user_error!("Release-note metadata exceeds #{MAX_RELEASE_NOTE_CHARACTERS} characters: #{path}")
      end
    end

    UI.success("Validated #{platform}/#{flavor} release-note metadata.")
    base
  end

  def self.review_attachment!(root:, flavor:)
    directory = File.join(root, "ios", "fastlane", "store_metadata", "review_attachments", flavor)
    files = Dir[File.join(directory, "*")].select { |path| File.file?(path) }

    UI.user_error!("App review attachment directory not found: #{directory}") unless Dir.exist?(directory)
    UI.user_error!("Exactly one App Store review attachment is required in #{directory}; found #{files.length}.") unless files.one?

    files.first
  end
end
