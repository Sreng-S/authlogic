module Authlogic
  module ORMAdapters
    module ActiveRecordAdapter
      module ActsAsAuthentic
        # = Persistence
        #
        # This is responsible for all record persistence. Basically what your Authlogic session needs to persist the record's session.
        #
        # === Class Methods
        #
        # * <tt>forget_all!</tt> - resets ALL records remember_token to a unique value, requiring all users to re-login
        # * <tt>unique_token</tt> - returns a pretty hardcore random token that is finally encrypted with a hash algorithm
        #
        # === Instance Methods
        #
        # * <tt>forget!</tt> - resets the record's remember_token which requires them to re-login
        #
        # === Alias Method Chains
        #
        # * <tt>#{options[:password_field]}</tt> - adds in functionality to reset the remember token when the password is changed
        module Persistence
          def acts_as_authentic_with_persistence(options = {})
            acts_as_authentic_without_persistence(options)
          
            validates_uniqueness_of options[:remember_token_field]
          
            def forget_all!
              # Paginate these to save on memory
              records = nil
              i = 0
              begin
                records = find(:all, :limit => 50, :offset => i)
                records.each { |record| record.forget! }
                i += 50
              end while !records.blank?
            end
          
            class_eval <<-"end_eval", __FILE__, __LINE__
              def self.unique_token
                # The remember token should be a unique string that is not reversible, which is what a hash is all about
                # if you using encryption this defaults to Sha512.
                token_class = #{options[:crypto_provider].respond_to?(:decrypt) ? Authlogic::CryptoProviders::Sha512 : options[:crypto_provider]}
                token_class.encrypt(Time.now.to_s + (1..10).collect{ rand.to_s }.join)
              end
            
              def forget!
                self.#{options[:remember_token_field]} = self.class.unique_token
                save_without_session_maintenance(false)
              end
            
              def #{options[:password_field]}_with_persistence=(value)
                self.#{options[:remember_token_field]} = self.class.unique_token
                self.#{options[:password_field]}_without_persistence = value
              end
              alias_method_chain :#{options[:password_field]}=, :persistence
            end_eval
          end
        end
      end
    end
  end
end

ActiveRecord::Base.class_eval do
  class << self
    include Authlogic::ORMAdapters::ActiveRecordAdapter::ActsAsAuthentic::Persistence
    alias_method_chain :acts_as_authentic, :persistence
  end
end