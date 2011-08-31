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
            
            def set_#{tag_field}_options(tags_with_options)
              set_tag_options(:#{tag_field}, tags_with_options)
            end
            
            def add_#{tag_field}(tags_with_options)
              set_tag_options(:#{tag_field}, tags_with_options)
            end
            
            def remove_#{tag_field}(tags)
              remove_tags_for(:#{tag_field}, tags)
            end
            
            def #{tag_field}_with_options
              tags_with_options_for(:#{tag_field})
            end
            
            def #{tag_field}_as_tree
              build_tree_for(:#{tag_field})
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
      
      #
      # this is not a good tree implementation, only supports 1. level, and is generally crap
      #
      def build_tree_for(context)
        result = []
        tags = tags_with_options_for(context)
        root_tags = tags.clone
        root_tags = root_tags.delete_if{|tag| !tag[1][:parent].blank?} 
        child_tags = tags - root_tags
        while(!child_tags.empty?)
          child_tags.each_with_index do |tag, index|
            parent = tag[1][:parent]
            root_tags.each do |root| 
              if root[0] == parent
                root[1][:children].blank? ? (root[1][:children] = [tag]) : (root[1][:children] << tag) 
                child_tags.delete_at(index)
              end
            end
          end
        end
        root_tags
      end
      
      def remove_tags_for(context, tags)
        tags.to_a.each do |tag_key| 
          #remove tag
          tags_by_context(context).delete(tag_key)
          #remove parent referance in other tags
          tags_by_context(context).each do |tag| 
            tag[1].delete(:parent)  if tag[1][:parent] && tag[1][:parent] == tag_key
          end
        end
      end
      
      def tags_by_context(context)
        self.send(context)
      end
    end
  end
end
