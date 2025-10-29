# frozen_string_literal: true
require 'yaml'
require 'fastlane_core/ui/ui'

module PubspecHelper
  UI = FastlaneCore::UI unless const_defined?(:UI)
  
  # 프로젝트 루트
  ROOT_DIR = File.expand_path(File.join(__dir__, "..", ".."))
  
  # pubspec.yaml 읽기
  def self.read_pubspec_versions
    YAML.load_file(File.join(ROOT_DIR, "pubspec.yaml"))
  end

  # "x.y.z+N" 튜플 반환
  # pubspec.yaml 예시:
  # version: 3.3.1+1        # (fallback)
  # app_versions:
  #   ios_regtest: 3.3.1+1
  #   ios_mainnet: 0.4.6+1
  # platform: "ios" | "aos", flavor: "regtest" | "mainnet"
  def self.version_tuple_for(platform:, flavor:)
    yml = read_pubspec_versions
    key = "#{platform}_#{flavor}"
    raw = yml.dig("app_versions", key) || yml["version"]
    UI.user_error!("version string not found in pubspec.yaml for key: app_versions.#{key} (and no global 'version')") unless raw

    m = raw.to_s.match(/\A(\d+\.\d+\.\d+)\+(\d+)\z/)
    UI.user_error!("version format must be x.y.z+build, got: #{raw}") unless m

    marketing = m[1]
    build     = m[2].to_i
    [marketing, build]
  end

  # pubspec.yaml의 특정 키(예: aos_regtest) 빌드넘버만 +1 (주석/포맷 보존)
  def self.update_pubspec_build_number(platform:, flavor:, marketing:, old_build:, new_build:)
    yml_path = File.join(ROOT_DIR, "pubspec.yaml")
    text = File.read(yml_path)

    key = "#{platform}_#{flavor}:"
    pattern = /^(\s*#{Regexp.escape(key)}\s*)(\d+\.\d+\.\d+)\+(\d+)/

    replaced = text.gsub(pattern) do
      prefix = Regexp.last_match(1)
      ver    = Regexp.last_match(2)
      bld    = Regexp.last_match(3).to_i
      "#{prefix}#{ver}+#{bld + 1}"
    end
    if replaced == text
      UI.user_error!("❌ 해당 항목을 찾지 못했습니다: #{key}")
    else
      File.write(yml_path, replaced)
      UI.message("✅ pubspec.yaml updated (#{key.strip}): #{marketing}+#{old_build} → #{marketing}+#{new_build}")
    end
  end
end