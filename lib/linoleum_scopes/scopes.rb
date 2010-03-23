module LinoleumScopes
  module Scopes

    #surely there's a built in way to do this. Since I'm clearly too stupid to find it, we'll arbitrarily support up to "twelve"
    STRING_TO_NUMBER_MAPPER = {
      :one => 1, :two => 2, :three => 3, :four => 4, :five => 5, :six => 6,
      :seven => 7, :eight => 8, :nine => 9, :ten => 10, :eleven => 11, :twelve => 12
    }

    UNITS = %w( seconds minutes hours days weeks months years )

    def self.included(base)
      base.extend(ClassMethods)      
    end

    module ClassMethods
      mattr_accessor :scoped_to
      def linoleum_scopes(*args)
        self.scoped_to = args && args.first.is_a?(Hash) ? (args[0][:using] || "created_at") : "created_at"
        raise ArgumentError.new("#{self.to_s} must implement #{self.scoped_to.to_s} for LinoleumScopes") unless self.new.respond_to?(self.scoped_to)
        
        scope :today, lambda{ where("DATE_FORMAT(#{self.scoped_to}, '%Y-%m-%d') = ?", Time.now.utc.strftime("%Y-%m-%d")) }
        scope :yesterday, lambda{ where("DATE_FORMAT(#{self.scoped_to}, '%Y-%m-%d') = ?", (Time.now.utc-1.day).strftime("%Y-%m-%d")) }
        scope :the_other_day, lambda{ where("DATE_FORMAT(#{self.scoped_to}, '%Y-%m-%d') = ?", (Time.now.utc-2.days).strftime("%Y-%m-%d")) }

        #find all objects on given formatted time
        scope :ago, lambda{ |scope|
          at = scope.scoped_at.ago
          #there's a potential gap here if the time frame is in seconds, I'd bet, based on the time diff from when the call actually gets evaluated and when it was made
          where("DATE_FORMAT(#{self.scoped_to}, '#{scope.date_formats_by_unit.first}') = ?", at.strftime(scope.date_formats_by_unit.last))
        }

        #find all objects _from_ formatted time to now
        scope :since, lambda{|scope|
          at = scope.scoped_at.ago
          where("DATE_FORMAT(#{self.scoped_to}, '#{scope.date_formats_by_unit.first}') >= ?", at.strftime(scope.date_formats_by_unit.last))
        }

        scope :hence, lambda{|scope|
          at = scope.scoped_at.since
          where("3=6")
        }
      end
      
      def method_missing(*args)
        if STRING_TO_NUMBER_MAPPER.keys.include?(args.first)          
          return self.new(:rate => STRING_TO_NUMBER_MAPPER[args.first.to_sym])
        end
        super
      end
    end

    #BEGIN instance methods
    mattr_accessor :rate
    mattr_accessor :unit
    def initialize(opts = {})      
      self.rate = opts[:rate] || 0
      self.unit = opts[:unit] || "second"
      super
    end

    #mysql and strftime use different values for date formatting
    def date_formats_by_unit
      #mysql format is always at first position, only one value if mysql and strftime are equivalent
      return ['%Y-%m-%d %H%i%s', '%Y-%m-%d %H%M%S'] if measured_in?("seconds")
      return ['%Y-%m-%d %H%i', '%Y-%m-%d %H%M'] if measured_in?("minutes")
      return ['%Y-%m-%d %H'] if measured_in?("hours")
      return ['%Y-%m-%d']
    end

    def measured_in?(unit)
      self.unit.pluralize == unit.pluralize
    end

    def scoped_at
      #eval is terrible!
      eval("#{self.rate}.#{self.unit}")
    end

    def method_missing(*args)
      #handle the units part of the chain
      self.unit = args.first.to_s and return self if UNITS.include?(args.first.to_s.pluralize)
      #if (:ago, :since, :hence) send up to corresponding named_scope...
      return self.class.send(args.first.to_sym, self) if %w(ago since hence).include?(args.first.to_s)
      super
    end

  end
end
