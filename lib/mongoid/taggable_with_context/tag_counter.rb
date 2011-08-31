module Mongoid::TaggableWithContext
  module TagCounter
    extend ActiveSupport::Concern
    
    module ClassMethods
      def count_tags_for(*args)

        args.each do |tag_field|
          
          field tag_field, :type => Hash, :default => {}
          
          #instance methods
          class_eval <<-END
            def #{tag_field}_with_weight
              tags_with_weight_for(:"#{tag_field}")
            end
            
            def set_#{tag_field}_options(options={})
              set_tag_options(:#{tag_field}, options)
            end
            
            def #{tag_field}_with_options
              tags_with_options_for(:#{tag_field})
            end
          END
        end
      end
    end
    
    module InstanceMethods
      private
      def tags_with_weight_for(context)
        result = []
        tags = tags_by_context(context)
        return unless tags
        tags.keys.each do |key|
          result << [key, tags[key][:count]]
        end
        result
      end
      
      def tags_with_options_for(context)
        result = []
        tags = tags_by_context(context)
        return unless tags
        tags.keys.each do |key|
          result << [key, tags[key]]
        end
        result
      end
            
      def set_tag_options(context, options={})
        tags = tags_by_context(context)
        options.each do |key, value|
          tags[key] = {:count => 0} unless tags[key]
          tag = tags[key]
          tag.merge!(value)
        end
      end
      
      def tags_by_context(context)
        self.send(context)
      end
    end
  end
end
