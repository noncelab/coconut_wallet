# frozen_string_literal: true
module UtilHelper
  # 문자열/불리언을 안전하게 true/false로 판별
  def self.truthy?(v)
    case v
    when true, "true", "1", 1, "yes", "y", :true then true
    else false
    end
  end
end