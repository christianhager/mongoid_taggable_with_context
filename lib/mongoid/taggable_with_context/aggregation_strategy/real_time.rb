module Mongoid::TaggableWithContext::AggregationStrategy
  module RealTime
    extend ActiveSupport::Concern
    
    included do
      set_callback :create,   :after, :increment_tags_agregation
      set_callback :save,     :after, :update_tags_aggregation
      set_callback :destroy,  :before, :store_reference_to_tag_counter
      set_callback :destroy,  :after, :decrement_tags_aggregation
    end
    
    module ClassMethods
      # Collection name for storing results of tag count aggregation
      def aggregation_collection_for(context)
        "#{collection_name}_#{context}_aggregation"
      end
      
      def tags_for(context, conditions={})
        conditions = {:sort => '_id'}.merge(conditions)
        db.collection(aggregation_collection_for(context)).find({:value => {"$gt" => 0 }}, conditions).to_a.map{ |t| t["_id"] }
      end

      # retrieve the list of tag with weight(count), this is useful for
      # creating tag clouds
      def tags_with_weight_for(context, conditions={})
        conditions = {:sort => '_id'}.merge(conditions)
        db.collection(aggregation_collection_for(context)).find({:value => {"$gt" => 0 }}, conditions).to_a.map{ |t| [t["_id"], t["value"]] }
      end
    end
    
    private
    def need_update_tags_aggregation?
      !changed_contexts.empty?
    end

    def changed_contexts
      tag_contexts & changes.keys.map(&:to_sym)
    end
    
    def increment_tags_agregation
      # if document is created by using MyDocument.new
      # and attributes are individually assigned
      # #changes won't be empty and aggregation
      # is updated in after_save, so we simply skip it.
      return unless changes.empty?

      # if the document is created by using MyDocument.create(:tags => "tag1 tag2")
      # #changes hash is empty and we have to update aggregation here
      tag_contexts.each do |context|
        coll = self.class.db.collection(self.class.aggregation_collection_for(context))
        field_name = self.class.tag_options_for(context)[:array_field]
        tags = self.send field_name || []
        tags.each do |t|
          coll.update({:_id => t}, {'$inc' => {:value => 1}}, :upsert => true)
          update_tag_counter(t, context, 1)
        end
      end
    end

    def decrement_tags_aggregation
      tag_contexts.each do |context|
        coll = self.class.db.collection(self.class.aggregation_collection_for(context))
        field_name = self.class.tag_options_for(context)[:array_field]
        tags = self.send field_name || []
        tags.each do |t|
          coll.update({:_id => t}, {'$inc' => {:value => -1}}, :upsert => true)
          update_tag_counter(t, context, -1)
        end
      end
    end

    def update_tags_aggregation
      return unless need_update_tags_aggregation?

      changed_contexts.each do |context|
        coll = self.class.db.collection(self.class.aggregation_collection_for(context))
        field_name = self.class.tag_options_for(context)[:array_field]        
        old_tags, new_tags = changes["#{field_name}"]
        old_tags ||= []
        new_tags ||= []
        unchanged_tags = old_tags & new_tags
        tags_removed = old_tags - unchanged_tags
        tags_added = new_tags - unchanged_tags

        tags_removed.each do |t|
          coll.update({:_id => t}, {'$inc' => {:value => -1}}, :upsert => true)
          update_tag_counter(t, context, -1)
        end

        tags_added.each do |t|
          coll.update({:_id => t}, {'$inc' => {:value => 1}}, :upsert => true)
          update_tag_counter(t, context, 1)
        end
      end
    end
    
    def store_reference_to_tag_counter
      @after_destroy_operatation = true
      tag_contexts.each do |context|
        counter_model_name = self.class.tag_options_for(context)[:counter_in]
        @tag_counter = self.send(counter_model_name) if counter_model_name
      end
    end
    
    def update_tag_counter(tag, context, val)
      return if @after_destroy_operation && !@tag_counter
      return if tag.blank?
      counter_model_name = self.class.tag_options_for(context)[:counter_in]
      return unless counter_model_name
      counter_model = @tag_counter
      counter_model = self.send(counter_model_name) unless counter_model
      return unless counter_model
      counter_hash = counter_model.send(context)
      return unless counter_hash
      unless counter_hash[tag]
        val == -1 ? false : (counter_hash[tag] = {:count => val})
      else
        counter_hash[tag][:count] += val
        counter_hash.delete(tag) if counter_hash[tag][:counter] == 0 #this should perhaps be optional?
      end  
      counter_model.send("#{context}=", counter_hash)
      mdl = (self.send(counter_model_name).class).find(counter_model.id) #hack to avoid the Frozen Hash error
      mdl.send("#{context}=", counter_hash)
      mdl.save
    end
  end
end