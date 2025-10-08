module Fastlane
  module Actions
    module SharedValues
    end

    class UpdateAppInfoAction < Action
      def self.run(params)
        require 'date'
        date = Time.now.strftime("%Y.%m.%d")
        content = File.read('lib/constants/app_info.dart')
        new_content = content.gsub(/const RELEASE_DATE = '[^']*'/, "const RELEASE_DATE = '#{date}'")
        File.write('lib/constants/app_info.dart', new_content)
      end

      def self.description
        'app_info.dart 파일의 RELEASE_DATE를 수정합니다.'
      end

      # def self.details
      # end

      # def self.available_options
      # end

      # def self.output
      # end

      # def self.return_value
      # end

      def self.authors
        ['Noncelab']
      end

      def self.is_supported?(platform)
          true
      end
    end
  end
end
