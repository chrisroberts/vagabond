module Vagabond
  class << self
    def get_bytes(s)
      s = s.to_s
      indx = [nil, 'k', 'm', 'g']
      power = indx.index(s.slice(-1, s.length).to_s.downcase).to_i * 10
      (2**power) * s.to_i
    end
  end
end
