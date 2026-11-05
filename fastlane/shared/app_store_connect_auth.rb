# frozen_string_literal: true
module AppStoreConnectAuth
  ENV_KEYS = %w[
    APP_STORE_CONNECT_API_KEY_KEY_ID
    APP_STORE_CONNECT_API_KEY_ISSUER_ID
    APP_STORE_CONNECT_API_KEY_KEY_FILEPATH
  ].freeze

  # App Store Connect 팀 API 키 옵션 (ios/fastlane/.env)
  def self.api_key_options!
    missing = ENV_KEYS.select { |key| ENV[key].to_s.strip.empty? }
    unless missing.empty?
      FastlaneCore::UI.user_error!("ios/fastlane/.env에 #{missing.join(', ')} 값이 필요합니다.")
    end

    # .env 값 끝의 공백·CR이 경로에 섞이면 있는 파일도 못 찾으므로 앞뒤 공백을 지웁니다.
    key_path = File.expand_path(ENV["APP_STORE_CONNECT_API_KEY_KEY_FILEPATH"].strip)
    FastlaneCore::UI.user_error!("API 키 파일이 없습니다: #{key_path}") unless File.file?(key_path)
    if (File.stat(key_path).mode & 0o077) != 0
      FastlaneCore::UI.user_error!("API 키 파일 권한이 넓습니다. chmod 600 #{key_path}")
    end

    {
      key_id: ENV["APP_STORE_CONNECT_API_KEY_KEY_ID"].strip,
      issuer_id: ENV["APP_STORE_CONNECT_API_KEY_ISSUER_ID"].strip,
      key_filepath: key_path
    }
  end
end
