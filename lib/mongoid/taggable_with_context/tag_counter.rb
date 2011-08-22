module Mongoid::TaggableWithContext
  module TagCounter
    extend ActiveSupport::Concern
    
    module InstanceMethods
      def tags_with_weight_for(tag_field)
        result = []
        self.send(tag_field).each do |field|
          result << [field, self.send(tag_field)[field]]
        end
        result
      end
    end
    
    module ClassMethods
      def count_tags_for(*args)

        args.each do |tag_field|
          
          field tag_field, :type => Hash, :default => {}
          
          class_eval <<-END
            class << self
              def #{tag_field}_with_weight
                tags_with_weight_for(:"#{tag_field}")
              end
            end
          END
        end
      end
    end
  end
end
